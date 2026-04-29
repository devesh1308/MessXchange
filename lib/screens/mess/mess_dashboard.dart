import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'entry_verification_screen.dart';

class MessDashboard extends StatelessWidget {
  const MessDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserData;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- THE FIX: Create the exact date string to match our new database logs ---
    DateTime now = DateTime.now();
    String todayDateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mess Admin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(user.name, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => authProvider.logout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- QR SCANNER BUTTON ---
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EntryVerificationScreen())),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.orangeAccent]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 60, color: Colors.white),
                    SizedBox(height: 12),
                    Text('Scan Student QR', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 4),
                    Text('Verify entry and deduct credits', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text('Today\'s Meal Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 16),

            // --- SEGREGATED STATS SECTION (SERVED ONLY) ---
            StreamBuilder<QuerySnapshot>(
              // --- THE FIX: Query by the exact date string instead of a timestamp range ---
              stream: FirebaseFirestore.instance.collection('meal_attendance')
                  .where('date_string', isEqualTo: todayDateString)
                  .snapshots(),
              builder: (context, attendanceSnap) {

                if (attendanceSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
                }

                // Count Served
                int bfServed = 0, lnServed = 0, dnServed = 0;
                if (attendanceSnap.hasData) {
                  for (var doc in attendanceSnap.data!.docs) {
                    String meal = (doc.data() as Map<String, dynamic>)['meal_type'] ?? '';
                    if (meal == 'breakfast') bfServed++;
                    if (meal == 'lunch') lnServed++;
                    if (meal == 'dinner') dnServed++;
                  }
                }

                return Column(
                  children: [
                    _buildMealRow('Breakfast', Icons.coffee, bfServed),
                    const SizedBox(height: 12),
                    _buildMealRow('Lunch', Icons.wb_sunny, lnServed),
                    const SizedBox(height: 12),
                    _buildMealRow('Dinner', Icons.nights_stay, dnServed),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Beautiful UI Card for each individual meal (Served only)
  Widget _buildMealRow(String title, IconData icon, int served) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.deepOrange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
                'Served: $served',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ),
        ],
      ),
    );
  }
}