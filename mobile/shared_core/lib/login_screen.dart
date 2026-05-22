import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import 'biometric_service.dart';


class LoginScreen extends StatefulWidget {
  final String role;
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.role, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  final _biometricService = BiometricService();

  void _login() async {
    setState(() => _isLoading = true);
    final user = await _authService.login(_emailController.text, _passwordController.text);
    setState(() => _isLoading = false);

    if (user != null) {
      final bool isSupported = await _biometricService.isBiometricsSupported();
      if (isSupported) {
        if (user.role == 'provider') {
          await _biometricService.setBiometricsEnabled(true);
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Biometric Lock Required'),
                content: const Text(
                  'In order to protect your merchant account, please enroll in biometric lock.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else if (user.role == 'customer' && user.isVerified) {
          final bool alreadyEnabled = await _biometricService.isBiometricsEnabled();
          if (!alreadyEnabled && mounted) {
            final bool? enable = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Enable Biometric Login?'),
                content: const Text('Enjoy passwordless login on your next visit.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not Now'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            if (enable == true) {
              await _biometricService.setBiometricsEnabled(true);
            }
          }
        }
      }
      widget.onLoginSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please check your credentials.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login as ${widget.role.toUpperCase()}')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      child: const Text('Login'),
                    ),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen(role: widget.role)),
                );
              },
              child: const Text('Don\'t have an account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
