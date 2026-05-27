import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

enum AuthStatus { authenticated, unauthenticated }

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  
  final _statusController = StreamController<AuthStatus>.broadcast();
  Stream<AuthStatus> get authStatus => _statusController.stream;

  NetworkService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      validateStatus: (status) => status! < 500,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        if (response.statusCode == 401) {
          await _storage.delete(key: 'jwt_token');
          _statusController.add(AuthStatus.unauthenticated);
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          await _storage.delete(key: 'jwt_token');
          _statusController.add(AuthStatus.unauthenticated);
        }
        return handler.next(e);
      },
    ));
  }

  void notifyAuthenticated() {
    _statusController.add(AuthStatus.authenticated);
  }

  void notifyUnauthenticated() {
    _statusController.add(AuthStatus.unauthenticated);
  }
}
