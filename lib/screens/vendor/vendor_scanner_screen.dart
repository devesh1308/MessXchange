import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VendorScannerScreen extends StatefulWidget {
  final double amount;      // Credits (e.g., 0.60 for 60 Rs)
  final double rupeeAmount; // Rupees (e.g., 60.0)

  const VendorScannerScreen({
    super.key,
    required this.amount,
    required this.rupeeAmount,
  });

  @override
  State<VendorScannerScreen> createState() => _VendorScannerScreenState();
}

class _VendorScannerScreenState extends State<VendorScannerScreen> {
  // HARDCODED VENDOR ID for Canteen 1
  final String _vendorId = "tJOwwgGfgPWDeMuYLaLozMyGQc52";

  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _processPayment(String scannedData) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    cameraController.stop();

    try {
      // ==========================================
      // 1. DYNAMIC QR VALIDATION (The 60-Second Rule)
      // ==========================================
      List<String> qrParts = scannedData.split('_');

      // If the QR code doesn't have exactly 2 parts (ID_Timestamp), it's invalid
      if (qrParts.length != 2) {
        throw Exception("Invalid QR Code.\nPlease ask the student to update their app.");
      }

      String studentId = qrParts[0];
      int qrTimestamp = int.tryParse(qrParts[1]) ?? 0;
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      // Allow a 65-second window (60s + 5s buffer for clock drift)
      if (currentTimestamp - qrTimestamp > 65000) {
        throw Exception("QR Code Expired!\nThis code is older than 60 seconds. Please scan a fresh one.");
      }

      // ==========================================
      // 2. FIREBASE TRANSACTION
      // ==========================================
      final studentRef = FirebaseFirestore.instance.collection('users').doc(studentId);
      String studentName = "Student";

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot studentSnapshot = await transaction.get(studentRef);

        if (!studentSnapshot.exists) {
          throw Exception("Student record not found!");
        }

        final studentData = studentSnapshot.data() as Map<String, dynamic>;
        studentName = studentData['name'] ?? "Student";

        // Safely access refund_credits (Default to 0.0 if missing)
        double currentRefundCredits = (studentData['refund_credits'] ?? 0.0).toDouble();

        // CHECK BALANCE (Math: 1 Credit = 100 Rs)
        if (currentRefundCredits < widget.amount) {
          double requiredRs = widget.amount * 100;
          double availableRs = currentRefundCredits * 100;

          throw Exception(
              "Insufficient Balance!\n"
                  "Required: ₹${requiredRs.toStringAsFixed(2)}\n"
                  "Available: ₹${availableRs.toStringAsFixed(2)}"
          );
        }

        // Deduct from 'refund_credits'
        transaction.update(studentRef, {
          'refund_credits': currentRefundCredits - widget.amount,
        });

        // Create the Sales Receipt
        DocumentReference txRef = FirebaseFirestore.instance.collection('vendor_transactions').doc();
        transaction.set(txRef, {
          'vendor_id': _vendorId,
          'vendor_name': "Canteen 1",
          'student_id': studentId,
          'student_name': studentName,
          'rupee_amount': widget.rupeeAmount,
          'credits_deducted': widget.amount,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'purchase',
        });
      });

      _showResultDialog(
          true,
          "Payment Successful!",
          "₹${widget.rupeeAmount.toStringAsFixed(2)} deducted from $studentName."
      );
    } catch (e) {
      String errorMsg = e.toString().replaceAll("Exception:", "").trim();
      _showResultDialog(false, "Payment Failed", errorMsg);
    }
  }

  void _showResultDialog(bool success, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 60,
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Go back to POS
              },
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Student QR"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processPayment(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "Billing Total: ₹${widget.rupeeAmount.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}