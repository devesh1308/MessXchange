import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
// Ensure this path matches your provider location:
import 'package:messxchangenew/providers/meal_provider.dart';

class EntryVerificationScreen extends StatefulWidget {
  const EntryVerificationScreen({super.key});

  @override
  State<EntryVerificationScreen> createState() => _EntryVerificationScreenState();
}

class _EntryVerificationScreenState extends State<EntryVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  Future<void> _processScannedQR(String scannedData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // ==========================================
      // 1. DYNAMIC QR VALIDATION (The 60-Second Rule)
      // ==========================================
      List<String> qrParts = scannedData.split('_');

      if (qrParts.length != 2) {
        _showResultDialog(false, "Invalid QR Format", "Please ask the student to update their app.");
        return;
      }

      String studentId = qrParts[0];
      int qrTimestamp = int.tryParse(qrParts[1]) ?? 0;
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      // Allow a 65-second window (60s + 5s buffer)
      if (currentTimestamp - qrTimestamp > 65000) {
        _showResultDialog(false, "QR Expired!", "This code is older than 60 seconds. Ask student for a fresh QR.");
        return;
      }

      // ==========================================
      // 2. MESS VERIFICATION LOGIC
      // ==========================================
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(studentId).get();

      if (!userDoc.exists) {
        _showResultDialog(false, "Invalid QR", "Student not found in database.");
        return;
      }

      String studentName = userDoc.get('name') ?? 'Student';
      int currentCredits = userDoc.get('mess_credits') ?? 0;

      if (currentCredits <= 0) {
        _showResultDialog(false, "Access Denied", "$studentName has 0 credits.");
        return;
      }

      // Show the meal selection choice
      _showMealSelectionDialog(studentId, studentName);

    } catch (e) {
      _showResultDialog(false, "Error", "Network issue. Try again.");
    }
  }

  void _showMealSelectionDialog(String userId, String studentName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Serving $studentName", textAlign: TextAlign.center),
        content: const Text("Select the meal to record:", textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          _mealButton(userId, studentName, 'breakfast', Colors.orange),
          _mealButton(userId, studentName, 'lunch', Colors.blue),
          _mealButton(userId, studentName, 'dinner', Colors.indigo),
        ],
      ),
    );
  }

  Widget _mealButton(String userId, String name, String type, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          onPressed: () => _finalizeEntry(userId, name, type),
          child: Text(type.toUpperCase()),
        ),
      ),
    );
  }

  // ==========================================
  // 3. GATEKEEPER & TRANSACTION LOGIC
  // ==========================================
  Future<void> _finalizeEntry(String userId, String studentName, String rawMealType) async {
    Navigator.pop(context); // Close selection dialog

    // Format 'lunch' to 'Lunch' so it matches your skipped meal database exactly
    String formattedMealType = rawMealType[0].toUpperCase() + rawMealType.substring(1).toLowerCase();

    try {
      // Get exact target date from your Provider logic
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      DateTime targetDate = mealProvider.getTargetDate(formattedMealType, DateTime.now());
      Timestamp targetTimestamp = Timestamp.fromDate(targetDate);

      // Create a simple date string (e.g., "2023-10-25") for easy duplicate checking
      String dateString = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

      // --- CHECK 1: DID THE STUDENT SKIP THIS MEAL? ---
      QuerySnapshot skipCheck = await _firestore
          .collection('meal_status')
          .where('user_id', isEqualTo: userId)
          .where('meal_type', isEqualTo: formattedMealType)
          .where('target_date', isEqualTo: targetTimestamp)
          .where('status', isEqualTo: 'skipped')
          .get();

      if (skipCheck.docs.isNotEmpty) {
        _showResultDialog(false, "Skipped Meal!", "$studentName cancelled their $formattedMealType for today. Do not serve.");
        return;
      }

      // --- CHECK 2: DUPLICATE SCAN CHECK ---
      QuerySnapshot duplicateCheck = await _firestore
          .collection('meal_attendance')
          .where('user_id', isEqualTo: userId)
          .where('meal_type', isEqualTo: rawMealType)
          .where('date_string', isEqualTo: dateString) // Using the new date string
          .get();

      if (duplicateCheck.docs.isNotEmpty) {
        _showResultDialog(false, "Duplicate Scan!", "$studentName already scanned in for $formattedMealType today.");
        return;
      }

      // --- ORIGINAL TRANSACTION: DEDUCT CREDITS & LOG ---
      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        DocumentSnapshot freshSnap = await transaction.get(userRef);
        int freshCredits = freshSnap.get('mess_credits');

        if (freshCredits > 0) {
          transaction.update(userRef, {'mess_credits': freshCredits - 1});

          // Log the entry with the new 'date_string' field so the duplicate check works next time
          transaction.set(_firestore.collection('meal_attendance').doc(), {
            'user_id': userId,
            'student_name': studentName,
            'timestamp': FieldValue.serverTimestamp(),
            'meal_type': rawMealType,
            'date_string': dateString, // <--- NEW: added for duplicate tracking
          });
        } else {
          throw Exception("ZeroCredits");
        }
      });

      _showResultDialog(true, "Success", "$studentName verified for $formattedMealType.");

    } catch (e) {
      if (e.toString().contains("ZeroCredits")) {
        _showResultDialog(false, "Access Denied", "$studentName has 0 credits.");
      } else {
        _showResultDialog(false, "Failed", "Could not complete transaction.");
      }
    }
  }

  void _showResultDialog(bool isSuccess, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Icon(isSuccess ? Icons.check_circle : Icons.cancel,
            color: isSuccess ? Colors.green : Colors.red, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) setState(() => _isProcessing = false);
                });
              },
              child: const Text("Scan Next"),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student QR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                return Icon(state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                    color: state == TorchState.on ? Colors.orange : Colors.grey);
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade50,
            width: double.infinity,
            child: const Text('Assign meal type after scanning student code.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (!_isProcessing && capture.barcodes.isNotEmpty) {
                      _processScannedQR(capture.barcodes.first.rawValue!);
                    }
                  },
                ),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.deepOrange, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                if (_isProcessing)
                  Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.deepOrange))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}