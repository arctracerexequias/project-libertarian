import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

class PaymentService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final _storage = const FlutterSecureStorage();

  PaymentService() {
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

  Future<Map<String, dynamic>?> initEscrow(String jobId, double amount) async {
    try {
      final response = await _dio.post('/payment/escrow/init', data: {
        'job_id': jobId,
        'amount': amount,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Init escrow error: $e');
    }
    return null;
  }

  Future<bool> releaseEscrow(String jobId) async {
    try {
      final response = await _dio.post('/payment/escrow/release', data: {
        'job_id': jobId,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('Release escrow error: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getEscrowStatus(String jobId) async {
    try {
      final response = await _dio.get('/payment/escrow/$jobId');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Get escrow status error: $e');
    }
    return null;
  }
}
