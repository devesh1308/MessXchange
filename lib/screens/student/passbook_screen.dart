import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PassbookScreen extends StatelessWidget {
  final String studentId;

  const PassbookScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Transaction History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vendor_transactions')
            .where('student_id', isEqualTo: studentId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error loading transactions.\n${snapshot.error}", textAlign: TextAlign.center));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final transactions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              var tx = transactions[index].data() as Map<String, dynamic>;
              return _buildTransactionCard(tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No transactions yet!",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "When you spend at the canteen,\nit will show up here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    bool isPurchase = (tx['type'] ?? 'purchase') == 'purchase';

    DateTime date = (tx['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    String formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);

    double rupeeAmount = (tx['rupee_amount'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPurchase ? Colors.red.shade50 : Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPurchase ? Icons.shopping_bag_rounded : Icons.account_balance_wallet_rounded,
            color: isPurchase ? Colors.redAccent : Colors.green,
          ),
        ),
        title: Text(
          tx['vendor_name'] ?? "Unknown Vendor",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(formattedDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ),
        trailing: Text(
          "${isPurchase ? '-' : '+'} ₹${rupeeAmount.toInt()}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isPurchase ? Colors.redAccent : Colors.green,
          ),
        ),
      ),
    );
  }
}