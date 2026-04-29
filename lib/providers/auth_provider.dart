import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUserData;
  bool _isLoading = false;

  UserModel? get currentUserData => _currentUserData;
  bool get isLoading => _isLoading;

  // Login Function
  Future<String?> loginUser(String email, String password, BuildContext context) async {
    try {
      _setLoading(true);

      // 1. Firebase Authentication
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (cred.user != null) {
        // 2. Fetch role from Firestore
        DocumentSnapshot doc = await _firestore.collection('users').doc(cred.user!.uid).get();

        if (doc.exists) {
          _currentUserData = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          notifyListeners();

          // 3. Verify role and return route for redirection
          _setLoading(false);
          return _getRouteForRole(_currentUserData!.role);
        } else {
          await _auth.signOut();
          _setLoading(false);
          return 'error: User record not found in database.';
        }
      }
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return 'error: ${e.message}';
    }
    _setLoading(false);
    return null;
  }

  // Logout Function
  Future<void> logout(BuildContext context) async {
    await _auth.signOut();
    _currentUserData = null;
    notifyListeners();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // Role Routing Logic
  String _getRouteForRole(String role) {
    switch (role.toLowerCase()) {
      case 'student': return '/student/dashboard';
      case 'mess': return '/mess/dashboard';
      case 'vendor': return '/vendor/dashboard';
      default: return '/login'; // Fallback
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}