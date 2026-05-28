import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const ProviderApp());
}

class ProviderApp extends StatelessWidget {
  const ProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libertarian Provider',
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
        if (_authService.currentUser == null) {
          await _authService.getProfile();
        }
      }

      final isSupported = await _biometricService.isBiometricsSupported();
      if (isSupported) {
        final enrolled = await _biometricService.isBiometricsEnabled();
        if (enrolled) {
          setState(() {
            _showLockScreen = true;
            _isLoading = false;
          });
        } else {
          // If not enrolled but token exists, force enroll and lock
          await _biometricService.setBiometricsEnabled(true);
          setState(() {
            _showLockScreen = true;
            _isLoading = false;
          });
        }
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
      return const ProviderMainContainer();
    } else {
      return LoginScreen(
        role: 'provider',
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

class ProviderMainContainer extends StatefulWidget {
  const ProviderMainContainer({super.key});

  @override
  State<ProviderMainContainer> createState() => _ProviderMainContainerState();
}

class _ProviderMainContainerState extends State<ProviderMainContainer> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DashboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
