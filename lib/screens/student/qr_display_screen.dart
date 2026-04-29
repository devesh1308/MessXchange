import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';

class QrDisplayScreen extends StatefulWidget {
  final String studentId;

  const QrDisplayScreen({super.key, required this.studentId});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  static String? _cachedQrData;
  static DateTime? _lastGeneratedTime;

  Timer? _refreshTimer;
  String _currentQrData = "";
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _initializeQr();

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAndRefreshQr();
    });
  }

  void _initializeQr() {
    final now = DateTime.now();

    // THE FIX: We added a check to see if the cached QR starts with the CURRENT student's ID.
    // If a new student logs in, this forces the app to throw away the old cache and make a new one!
    bool isCacheExpired = _lastGeneratedTime == null || now.difference(_lastGeneratedTime!).inSeconds >= 60;
    bool isDifferentStudent = _cachedQrData == null || !_cachedQrData!.startsWith('${widget.studentId}_');

    if (isCacheExpired || isDifferentStudent) {
      _generateNewQr(now);
    } else {
      _currentQrData = _cachedQrData!;
      _secondsRemaining = 60 - now.difference(_lastGeneratedTime!).inSeconds;
    }
  }

  void _generateNewQr(DateTime now) {
    setState(() {
      _cachedQrData = '${widget.studentId}_${now.millisecondsSinceEpoch}';
      _lastGeneratedTime = now;

      _currentQrData = _cachedQrData!;
      _secondsRemaining = 60;
    });
  }

  void _checkAndRefreshQr() {
    final now = DateTime.now();
    if (_lastGeneratedTime != null) {
      int diff = now.difference(_lastGeneratedTime!).inSeconds;

      if (diff >= 60) {
        _generateNewQr(now);
      } else {
        if (mounted) {
          setState(() {
            _secondsRemaining = 60 - diff;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Scan at Canteen/Mess",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "This code is dynamic and prevents screenshot fraud.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: QrImageView(
              data: _currentQrData,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _secondsRemaining / 60,
                  backgroundColor: Colors.grey.shade200,
                  color: _secondsRemaining < 10 ? Colors.red : Colors.deepOrange,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Refreshes in $_secondsRemaining seconds",
                style: TextStyle(
                  color: _secondsRemaining < 10 ? Colors.red : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}