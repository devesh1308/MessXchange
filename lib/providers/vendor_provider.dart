import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorProvider extends ChangeNotifier {

  /// Processes a partial or full payment securely using a Firebase Transaction
  Future<void> processCanteenPayment(BuildContext context, String studentId, double totalBill) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(studentId);

    try {
      // 1. Start a secure transaction
      Map<String, dynamic> result = await FirebaseFirestore.instance.runTransaction((transaction) async {

        // 2. Read the student's current balance
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Student not found!");

        double currentBalance = (snapshot.data() as Map<String, dynamic>)['refund_credits'] ?? 0.0;

        // 3. Do the Math (Find the minimum between balance and bill)
        double amountToDeduct = (currentBalance >= totalBill) ? totalBill : currentBalance;
        double cashToCollect = totalBill - amountToDeduct;

        // 4. Update the Student's Balance
        transaction.update(docRef, {
          'refund_credits': currentBalance - amountToDeduct,
        });

        // 5. Write the Passbook Receipt (Only record what left the wallet)
        DocumentReference receiptRef = FirebaseFirestore.instance.collection('vendor_transactions').doc();
        transaction.set(receiptRef, {
          'student_id': studentId,
          'vendor_name': 'Canteen Purchase',
          'type': 'purchase',
          'rupee_amount': amountToDeduct,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Return the math back to the app so the Vendor knows what to do
        return {
          'wallet_deducted': amountToDeduct,
          'cash_to_collect': cashToCollect,
        };
      });

      // 6. Show the UI SnackBar to the Vendor
      if (!context.mounted) return;

      if (result['cash_to_collect'] > 0) {
        // Partial Payment Scenario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Split: ₹${result['wallet_deducted']} from wallet. COLLECT ₹${result['cash_to_collect']} IN CASH!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        // Full Payment Scenario
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Complete! Fully paid from wallet.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      debugPrint("Payment Error: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction Failed. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}