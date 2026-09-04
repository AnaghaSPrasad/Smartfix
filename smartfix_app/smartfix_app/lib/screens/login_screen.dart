import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'customer_home_screen.dart';
import 'worker_home_screen.dart';
import 'admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.build_circle, size: 72, color: Colors.blueAccent),
              const SizedBox(height: 12),
              const Text(
                'SmartFix',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Book trusted home services',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (auth.errorMessage != null)
                Text(
                  auth.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final success = await auth.login(
                          _usernameController.text.trim(),
                          _passwordController.text,
                        );
                        if (success && context.mounted) {
                          Widget destination;
                          switch (auth.role) {
                            case 'worker':
                              destination = const WorkerHomeScreen();
                              break;
                            case 'admin':
                              destination = const AdminHomeScreen();
                              break;
                            default:
                              destination = const CustomerHomeScreen();
                          }
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => destination),
                            (route) => false,
                          );
                        }
                      },
                child: auth.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log In'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
