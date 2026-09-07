import 'package:dio/dio.dart';
import 'network_service.dart';

class BoostService {
  final Dio _dio = NetworkService().dio;

  Future<bool> purchaseCoverageBoost() async {
    try {
      final response = await _dio
          .post('/identity/auth/boost/coverage', data: {'duration_days': 7});
      return response.statusCode == 200;
    } catch (e) {
      print('Purchase coverage boost error: $e');
    }
    return false;
  }

  Future<bool> purchaseRoamBoost() async {
    try {
      final response = await _dio
          .post('/identity/auth/boost/roam', data: {'duration_days': 7});
      return response.statusCode == 200;
    } catch (e) {
      print('Purchase roam boost error: $e');
    }
    return false;
  }

  Future<bool> toggleCoverageBoost(bool enabled) async {
    try {
      final response =
          await _dio.post('/identity/auth/boost/coverage/toggle', data: {
        'active': enabled,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('Toggle coverage boost error: $e');
    }
    return false;
  }
}
