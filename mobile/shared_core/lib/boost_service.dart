import 'package:dio/dio.dart';
import 'network_service.dart';

class BoostService {
  final Dio _dio = NetworkService().dio;

  Future<bool> purchaseCoverageBoost() async {
    try {
      // Mock payment delay
      await Future.delayed(const Duration(seconds: 2));
      final response = await _dio.post('/identity/auth/boost/coverage');
      return response.statusCode == 200;
    } catch (e) {
      print('Purchase coverage boost error: $e');
    }
    return false;
  }

  Future<bool> purchaseRoamBoost() async {
    try {
      // Mock payment delay
      await Future.delayed(const Duration(seconds: 2));
      final response = await _dio.post('/identity/auth/boost/roam');
      return response.statusCode == 200;
    } catch (e) {
      print('Purchase roam boost error: $e');
    }
    return false;
  }

  Future<bool> toggleCoverageBoost(bool enabled) async {
    try {
      final response = await _dio.post('/identity/auth/boost/coverage/toggle', data: {
        'enabled': enabled,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('Toggle coverage boost error: $e');
    }
    return false;
  }
}
