import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import 'qr_display_screen.dart'; // Phase 5: QR Code Screen
import 'passbook_screen.dart'; // Added: Passbook Screen Import

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch today's menu from Firebase when the dashboard loads
    Future.microtask(() =>
        Provider.of<MealProvider>(context, listen: false).fetchTodayMenu());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserData;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Moved the tabs array inside build() so we can pass the dynamic user.id
    final List<Widget> tabs = [
      const StudentHomeScreen(),
      QrDisplayScreen(studentId: user.id), // Connected to your new dynamic QR screen
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Hi, ${user.name}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            Text(
                '${user.messCredits} Meals Remaining',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12)
            ),
          ],
        ),
        actions: [
          // Spendable Refund Wallet (Green) - NOW CLICKABLE
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PassbookScreen(studentId: user.id),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Center(
                child: Text(
                  '₹${(user.refundCredits * 100).toInt()}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => authProvider.logout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_rounded), label: 'My QR'),
        ],
      ),
    );
  }
}

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<MealProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Meal Planner',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
          ),
          const Text(
              'Plan your presence or skip for refunds',
              style: TextStyle(color: Colors.grey)
          ),
          const SizedBox(height: 20),

          _buildMealCard(context, p, 'Breakfast', '07:30 - 09:30', Icons.coffee_rounded, Colors.brown),
          const SizedBox(height: 12),
          _buildMealCard(context, p, 'Lunch', '13:00 - 15:00', Icons.wb_sunny_rounded, Colors.orange),
          const SizedBox(height: 12),
          _buildMealCard(context, p, 'Dinner', '20:00 - 22:00', Icons.nights_stay_rounded, Colors.blueGrey),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // Bottom Legend for Refund Rules
          Center(
            child: Text(
              'Refunds: ≥4h: 80% | ≥3h: 50% | ≥2h: 20% | <1h: 0%',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(BuildContext ctx, MealProvider p, String type, String time, IconData icon, Color color) {
    final now = DateTime.now();
    final target = p.getTargetDate(type, now);

    // details contains {'value': 0.8, 'percent': '80%'}
    final details = p.getRefundDetails(type, now, target);

    final double refundValue = details['value'];
    final String refundPercent = details['percent'];

    final bool isServing = refundValue == -1.0;
    final bool isTomorrow = target.day != now.day;
    final bool isZeroRefund = refundValue == 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
            '$type ${isTomorrow ? "(Tomorrow)" : ""}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              'Menu: ${isTomorrow ? p.tomorrowMenu[type] : p.todayMenu[type]}', // <-- Swaps dynamically!
              style: TextStyle(color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: (p.isLoading || isServing) ? null : () {
            _showSkipConfirmation(ctx, p, type, target, refundValue, refundPercent, isZeroRefund);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isServing ? Colors.grey.shade200 : Colors.red.shade50,
            foregroundColor: isServing ? Colors.grey : Colors.red,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: p.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isServing ? 'Serving' : 'Skip', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showSkipConfirmation(BuildContext ctx, MealProvider p, String type, DateTime target, double val, String percent, bool isZero) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Skip $type?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target Date: ${target.day}/${target.month}/${target.year}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Refund Rate:', style: TextStyle(fontSize: 16)),
                Text(
                    percent,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isZero ? Colors.orange : Colors.green
                    )
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to Wallet:', style: TextStyle(fontSize: 16)),
                Text(
                    '₹${(val * 100).toInt()}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isZero ? Colors.orange : Colors.green
                    )
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              isZero
                  ? 'Warning: You are within the 1-hour window. You will consume 1 Mess Credit but receive ₹0.'
                  : 'Note: 1 Mess Credit will be consumed for this skip.',
              style: TextStyle(fontSize: 12, color: isZero ? Colors.red : Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              p.skipMeal(ctx, type, target, val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Skip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}