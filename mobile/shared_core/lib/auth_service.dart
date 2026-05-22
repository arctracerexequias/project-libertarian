import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';
import 'models.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final _storage = const FlutterSecureStorage();

  AuthService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

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
        return UserProfile(
          id: response.data['id'],
          fullName: fullName,
          email: email,
          role: role,
        );
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
        return UserProfile.fromJson(response.data['user']);
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
        return UserProfile.fromJson(response.data);
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
      return response.statusCode == 200;
    } catch (e) {
      print('Update profile error: $e');
    }
    return false;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<bool> verifyMe() async {
    try {
      final response = await _dio.post('/identity/auth/verify-me');
      return response.statusCode == 200;
    } catch (e) {
      print('Verification error: $e');
    }
    return false;
  }
}
