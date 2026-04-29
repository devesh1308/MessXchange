import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// --- Generated Firebase Options ---
import 'firebase_options.dart';

// --- Providers ---
import 'providers/auth_provider.dart';
import 'providers/meal_provider.dart';
import 'package:messxchangenew/providers/vendor_provider.dart';

// --- Screens ---
import 'package:messxchangenew/screens/auth_wrapper.dart'; // <-- Added AuthWrapper
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard.dart';

// --- Placeholder Screens for Future Phases ---
class MessDashboard extends StatelessWidget {
  const MessDashboard({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Mess Dashboard')));
}

class VendorDashboard extends StatelessWidget {
  const VendorDashboard({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Vendor Dashboard')));
}
// -----------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
      ],
      child: const MessXchangeApp(),
    ),
  );
}

class MessXchangeApp extends StatelessWidget {
  const MessXchangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MessXchange',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),

      // --- UPDATED ROUTING LOGIC ---
      // The AuthWrapper now handles deciding whether to show Login or Dashboard
      home: const AuthWrapper(),

      // We keep these routes in case you are using Navigator.pushNamed anywhere else
      routes: {
        '/login': (context) => const LoginScreen(),
        '/student/dashboard': (context) => const StudentDashboard(),
        '/mess/dashboard': (context) => const MessDashboard(),
        '/vendor/dashboard': (context) => const VendorDashboard(),
      },
    );
  }
}