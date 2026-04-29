import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:messxchangenew/screens/auth/login_screen.dart';
import 'package:messxchangenew/screens/student/student_dashboard.dart';
import 'package:messxchangenew/screens/vendor/vendor_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Listen to Firebase Auth state changes (Logged In vs Logged Out)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        // If still checking auth state, show a tiny loading spinner
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If user is NOT logged in, show Login Screen immediately
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        // 2. If user IS logged in, fetch their role from Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(authSnapshot.data!.uid).get(),
          builder: (context, userSnapshot) {

            // While fetching the role, show a tiny loading spinner
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              // If there's an error finding the user document, force them to login
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            // 3. Route based on role
            String role = userSnapshot.data!['role'] ?? 'student';

            if (role == 'vendor') {
              return const VendorDashboard();
            } else {
              return const StudentDashboard();
            }
          },
        );
      },
    );
  }
}