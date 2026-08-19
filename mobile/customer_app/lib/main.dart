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
  final ValueNotifier<int> _historyRefresh = ValueNotifier(0);

  late final List<Widget> _tabs = [
    HomeScreen(historyRefresh: _historyRefresh),
    const ProfileScreen(),
    CustomerHistoryScreen(refreshSignal: _historyRefresh),
    const CustomerHelpScreen(),
  ];

  @override
  void dispose() {
    _historyRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: CustomerBottomMenu(
        selectedIndex: _currentIndex,
        onSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class CustomerBottomMenu extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CustomerBottomMenu({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = <(String, IconData)>[
    ('Home', Icons.home_outlined),
    ('Profile', Icons.person_rounded),
    ('History', Icons.assignment_outlined),
    ('Help', Icons.question_mark_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = selectedIndex == index;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: '${item.$1} tab',
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 7, bottom: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.$2,
                            size: 32,
                            color: const Color(0xFF006996),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.$1,
                            maxLines: 1,
                            style: TextStyle(
                              color: const Color(0xFF00577D),
                              fontFamily: 'serif',
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
