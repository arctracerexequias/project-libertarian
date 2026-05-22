import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';
import 'package:latlong2/latlong.dart';

class DispatchService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final _storage = const FlutterSecureStorage();

  DispatchService() {
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

  Future<void> updateLocation(String providerId, Position position) async {
    try {
      await _dio.post('/dispatch/location', data: {
        'provider_id': providerId,
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (e) {
      print('Update location error: $e');
    }
  }

  Future<Map<String, dynamic>?> getProviderLocation(String providerId) async {
    try {
      final response = await _dio.get('/dispatch/location/$providerId');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Get provider location error: $e');
    }
    return null;
  }

  Future<List<LatLng>> getNearbyProviders(double lat, double lng, String category) async {
    try {
      final response = await _dio.post('/dispatch/dispatch', data: {
        'lat': lat,
        'lng': lng,
        'category': category,
        'radius': 10000, // 10km radius for discovery
      });
      if (response.statusCode == 200) {
        final List locations = response.data['locations'];
        return locations.map((loc) => LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        )).toList();
      }
    } catch (e) {
      print('Get nearby providers error: $e');
    }
    return [];
  }

  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Geolocator exception: $e');
      return null;
    }
  }
}
