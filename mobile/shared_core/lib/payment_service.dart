import 'package:dio/dio.dart';
import 'network_service.dart';

class PaymentService {
  final Dio _dio = NetworkService().dio;

  PaymentService();

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
