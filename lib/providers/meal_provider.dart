import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../models/app_models.dart';

class MealProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isVerifying = false; // NEW: Loading state for the scanner screen

  Map<String, String> _todayMenu = {
    'Breakfast': 'Loading...',
    'Lunch': 'Loading...',
    'Dinner': 'Loading...',
  };

  Map<String, String> _tomorrowMenu = {
    'Breakfast': 'Loading...',
    'Lunch': 'Loading...',
    'Dinner': 'Loading...',
  };

  bool get isLoading => _isLoading;
  bool get isVerifying => _isVerifying; // NEW: Getter for scanner
  Map<String, String> get todayMenu => _todayMenu;
  Map<String, String> get tomorrowMenu => _tomorrowMenu;

  Future<void> fetchTodayMenu() async {
    try {
      int todayIndex = DateTime.now().weekday - 1;
      int tomorrowIndex = (todayIndex + 1) % 7;
      List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

      String todayName = days[todayIndex];
      String tomorrowName = days[tomorrowIndex];

      final results = await Future.wait([
        _firestore.collection('menu').doc(todayName).get(),
        _firestore.collection('menu').doc(tomorrowName).get(),
      ]);

      if (results[0].exists) {
        Map<String, dynamic> data = results[0].data() as Map<String, dynamic>;
        _todayMenu = {
          'Breakfast': data['breakfast'] ?? 'Not Set',
          'Lunch': data['lunch'] ?? 'Not Set',
          'Dinner': data['dinner'] ?? 'Not Set',
        };
      }

      if (results[1].exists) {
        Map<String, dynamic> data = results[1].data() as Map<String, dynamic>;
        _tomorrowMenu = {
          'Breakfast': data['breakfast'] ?? 'Not Set',
          'Lunch': data['lunch'] ?? 'Not Set',
          'Dinner': data['dinner'] ?? 'Not Set',
        };
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Menu Error: $e");
    }
  }

  DateTime getTargetDate(String mealType, DateTime currentTime) {
    int endHour = (mealType == 'Breakfast') ? 9 : (mealType == 'Lunch' ? 15 : 22);
    int endMin = (mealType == 'Breakfast') ? 30 : 0;

    DateTime todayMealEnd = DateTime(currentTime.year, currentTime.month, currentTime.day, endHour, endMin);

    if (currentTime.isAfter(todayMealEnd)) {
      return DateTime(currentTime.year, currentTime.month, currentTime.day + 1);
    }
    return DateTime(currentTime.year, currentTime.month, currentTime.day);
  }

  Map<String, dynamic> getRefundDetails(String mealType, DateTime currentTime, DateTime targetDate) {
    int startHour = (mealType == 'Breakfast') ? 7 : (mealType == 'Lunch' ? 13 : 20);
    int startMin = (mealType == 'Breakfast') ? 30 : 0;
    int endHour = (mealType == 'Breakfast') ? 9 : (mealType == 'Lunch' ? 15 : 22);
    int endMin = (mealType == 'Breakfast') ? 30 : 0;

    DateTime mealStartTime = DateTime(targetDate.year, targetDate.month, targetDate.day, startHour, startMin);
    DateTime mealEndTime = DateTime(targetDate.year, targetDate.month, targetDate.day, endHour, endMin);

    if ((currentTime.isAfter(mealStartTime) || currentTime.isAtSameMomentAs(mealStartTime)) &&
        currentTime.isBefore(mealEndTime)) {
      return {'value': -1.0, 'percent': '0%'};
    }

    double hoursRemaining = mealStartTime.difference(currentTime).inMinutes / 60.0;

    if (hoursRemaining >= 4) return {'value': 0.8, 'percent': '80%'};
    if (hoursRemaining >= 3) return {'value': 0.5, 'percent': '50%'};
    if (hoursRemaining >= 2) return {'value': 0.2, 'percent': '20%'};

    return {'value': 0.0, 'percent': '0%'};
  }

  Future<void> skipMeal(BuildContext context, String mealType, DateTime targetDate, double refundValue) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserData;

    if (user == null || refundValue < 0) return;

    _setLoading(true);
    try {
      final checkSnapshot = await _firestore
          .collection('meal_status')
          .where('user_id', isEqualTo: user.id)
          .where('meal_type', isEqualTo: mealType)
          .where('target_date', isEqualTo: Timestamp.fromDate(targetDate))
          .get();

      if (checkSnapshot.docs.isNotEmpty) {
        _setLoading(false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already skipped this meal!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _firestore.collection('users').doc(user.id).update({
        'mess_credits': user.messCredits - 1,
        'refund_credits': user.refundCredits + refundValue,
      });

      await _firestore.collection('meal_status').add({
        'user_id': user.id,
        'meal_type': mealType,
        'target_date': Timestamp.fromDate(targetDate),
        'status': 'skipped',
        'refund_awarded': refundValue,
        'action_timestamp': FieldValue.serverTimestamp(),
      });

      double rupeeAmount = refundValue * 100;

      await _firestore.collection('vendor_transactions').add({
        'student_id': user.id,
        'vendor_name': 'Mess Refund ($mealType)',
        'type': 'refund',
        'rupee_amount': rupeeAmount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await authProvider.loginUser(user.email, '123456', context);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(refundValue == 0.0
              ? 'Meal skipped. ₹0 refunded (Grace Window).'
              : 'Skipped! ₹${(refundValue * 100).toInt()} added to wallet.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Skip Transaction Error: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Try again.'), backgroundColor: Colors.red),
      );
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // =========================================================================
  // NEW: THE GATEKEEPER LOGIC (For Mess Admin Scanner)
  // =========================================================================
  Future<String> verifyStudentEntry(String studentId, String mealType) async {
    _isVerifying = true;
    notifyListeners();

    try {
      // 1. Verify Student exists
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(studentId).get();
      if (!userDoc.exists) {
        return "ERROR: Invalid QR Code. Student not found.";
      }

      // Determine the exact Target Date using your existing Rollover Logic
      DateTime now = DateTime.now();
      DateTime targetDate = getTargetDate(mealType, now);
      Timestamp targetTimestamp = Timestamp.fromDate(targetDate);

      // 2. CHECK IF SKIPPED: Match against your existing `meal_status` logic
      QuerySnapshot skipCheck = await _firestore
          .collection('meal_status')
          .where('user_id', isEqualTo: studentId)
          .where('meal_type', isEqualTo: mealType)
          .where('target_date', isEqualTo: targetTimestamp)
          .where('status', isEqualTo: 'skipped') // Ensure we only block if they skipped
          .get();

      if (skipCheck.docs.isNotEmpty) {
        return "SKIPPED: Student has cancelled their $mealType today!";
      }

      // 3. CHECK DUPLICATE ENTRY: Have they already scanned in today?
      QuerySnapshot logCheck = await _firestore
          .collection('meal_entry_logs')
          .where('student_id', isEqualTo: studentId)
          .where('meal_type', isEqualTo: mealType)
          .where('target_date', isEqualTo: targetTimestamp)
          .get();

      if (logCheck.docs.isNotEmpty) {
        return "DUPLICATE: Student already scanned in for $mealType!";
      }

      // 4. LOG SUCCESSFUL ENTRY
      await _firestore.collection('meal_entry_logs').add({
        'student_id': studentId,
        'meal_type': mealType,
        'target_date': targetTimestamp,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get the student's name from the document for a nicer UI experience
      String studentName = (userDoc.data() as Map<String, dynamic>)['name'] ?? 'Student';
      return "SUCCESS: Allowed entry for $studentName.";

    } catch (e) {
      debugPrint("Verify Entry Error: $e");
      return "ERROR: Database connection failed.";
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }
}