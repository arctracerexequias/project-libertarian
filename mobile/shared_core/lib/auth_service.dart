import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'network_service.dart';
import 'models.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final Dio _dio = NetworkService().dio;
  final _storage = const FlutterSecureStorage();
  
  Stream<AuthStatus> get status => NetworkService().authStatus;
  
  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  
  final _userController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get userStream => _userController.stream;

  AuthService._internal();

  Future<UserProfile?> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      final response = await _dio.post('/identity/auth/register', data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      });

      if (response.statusCode == 201) {
        final profile = UserProfile(
          id: response.data['id'],
          fullName: fullName,
          email: email,
          role: role,
        );
        return profile;
      }
    } catch (e) {
      print('Registration error: $e');
    }
    return null;
  }

  Future<UserProfile?> login(String email, String password) async {
    try {
      final response = await _dio.post('/identity/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        await _storage.write(key: 'jwt_token', value: token);
        
        final profile = UserProfile.fromJson(response.data['user']);
        _currentUser = profile;
        _userController.add(_currentUser);
        
        NetworkService().notifyAuthenticated();
        return profile;
      }
    } catch (e) {
      print('Login error: $e');
    }
    return null;
  }

  Future<UserProfile?> getProfile() async {
    try {
      final response = await _dio.get('/identity/auth/profile');
      if (response.statusCode == 200) {
        final profile = UserProfile.fromJson(response.data);
        _currentUser = profile;
        _userController.add(_currentUser);
        return profile;
      }
    } catch (e) {
      print('Get profile error: $e');
    }
    return null;
  }

  Future<bool> updateProfile(String fullName, String bio, List<String> skills) async {
    try {
      final response = await _dio.put('/identity/auth/profile',
          data: {'full_name': fullName, 'bio': bio, 'skills': skills});
      if (response.statusCode == 200) {
        await getProfile(); // Refresh cache
        return true;
      }
    } catch (e) {
      print('Update profile error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    _currentUser = null;
    _userController.add(null);
    NetworkService().notifyUnauthenticated();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<bool> verifyMe() async {
    try {
      final response = await _dio.post('/identity/auth/verify-me');
      if (response.statusCode == 200) {
        await getProfile(); // Auto-load profile data on verification
        return true;
      } else if (response.statusCode == 401) {
        _currentUser = null;
        _userController.add(null);
        NetworkService().notifyUnauthenticated();
      }
    } catch (e) {
      print('Verification error: $e');
    }
    return false;
  }

  void dispose() {
    _userController.close();
  }
}
