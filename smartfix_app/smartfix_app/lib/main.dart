import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/customer_home_screen.dart';
import 'screens/worker_home_screen.dart';
import 'screens/admin_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFixApp());
}

class SmartFixApp extends StatelessWidget {
  const SmartFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkLoginStatus(),
      child: MaterialApp(
        title: 'SmartFix',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blueAccent,
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),

          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    switch (auth.role) {
      case 'worker':
        return const WorkerHomeScreen();
      case 'admin':
        return const AdminHomeScreen();
      default:
        return const CustomerHomeScreen();
    }
  }
}