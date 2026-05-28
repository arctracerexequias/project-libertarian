import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libertarian Customer',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  StreamSubscription<AuthStatus>? _authSubscription;

  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _showLockScreen = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _authSubscription = _authService.status.listen((status) {
      if (status == AuthStatus.unauthenticated) {
        setState(() {
          _isLoggedIn = false;
          _showLockScreen = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialAuth() async {
    final token = await _authService.getToken();
    if (token != null) {
      // Pre-verify token before showing biometric lock
      final bool isValid = await _authService.verifyMe();
      if (!isValid) {
        final stillExists = await _authService.getToken();
        if (stillExists == null) {
          if (mounted) {
            setState(() {
              _isLoggedIn = false;
              _isLoading = false;
            });
          }
          return;
        }
      } else {
        // Token is valid, profile should have been fetched by verifyMe
        // but we ensure it's loaded here just in case.
        if (_authService.currentUser == null) {
          await _authService.getProfile();
        }
      }

      final hasBiometrics = await _biometricService.isBiometricsEnabled();
      if (hasBiometrics) {
        setState(() {
          _showLockScreen = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  void _handleSignOut() async {
    await _biometricService.clearSettings();
    await _authService.logout();
    setState(() {
      _isLoggedIn = false;
      _showLockScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showLockScreen) {
      return BiometricLockScreen(
        onUnlockSuccess: () {
          setState(() {
            _showLockScreen = false;
            _isLoggedIn = true;
          });
        },
        onSignOut: _handleSignOut,
      );
    }

    if (_isLoggedIn) {
      return const CustomerMainContainer();
    } else {
      return LoginScreen(
        role: 'customer',
        onLoginSuccess: () {
          setState(() {
            _isLoggedIn = true;
            _showLockScreen = false;
          });
        },
      );
    }
  }
}

class CustomerMainContainer extends StatefulWidget {
  const CustomerMainContainer({super.key});

  @override
  State<CustomerMainContainer> createState() => _CustomerMainContainerState();
}

class _CustomerMainContainerState extends State<CustomerMainContainer> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
