import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'config.dart';
import 'models.dart';

class MarketplaceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final _storage = const FlutterSecureStorage();

  MarketplaceService() {
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

  Future<List<Job>> getJobs({String? category, double? lat, double? lng, double? radius}) async {
    try {
      final response = await _dio.get('/marketplace/jobs/', queryParameters: {
        if (category != null) 'category': category,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radius != null) 'radius': radius,
      });
      if (response.statusCode == 200) {
        final List jobsData = response.data['jobs'];
        return jobsData.map((json) => Job(
          id: json['id'],
          title: json['title'],
          description: json['description'],
          category: json['category'],
          status: _parseStatus(json['status']),
          maxBudget: (json['max_budget'] as num?)?.toDouble(),
          location: (json['lat'] != null && json['lng'] != null) 
            ? LatLng(json['lat'], json['lng']) 
            : null,
          createdAt: DateTime.parse(json['created_at']),
        )).toList();
      }
    } catch (e) {
      print('Get jobs error: $e');
    }
    return [];
  }

  Future<List<Bid>> getBids(String jobId) async {
    try {
      final response = await _dio.get('/marketplace/jobs/$jobId/bids');
      if (response.statusCode == 200) {
        final List bidsData = response.data['bids'];
        return bidsData.map((json) => Bid.fromJson(json)).toList();
      }
    } catch (e) {
      print('Get bids error: $e');
    }
    return [];
  }

  Future<Bid?> submitBid({
    required String jobId,
    required double amount,
    required String estimatedTime,
    String? message,
  }) async {
    try {
      final response = await _dio.post(
        '/marketplace/jobs/$jobId/bids',
        data: {
          'amount': amount,
          'estimated_time': estimatedTime,
          'message': message,
        },
      );

      if (response.statusCode == 201) {
        final id = response.data['id'];
        return Bid(
          id: id,
          jobId: jobId,
          providerId: '',
          amount: amount,
          estimatedTime: estimatedTime,
          message: message ?? '',
          status: 'pending',
          providerRating: 5.0,
          providerVerified: false,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Submit bid error: $e');
    }
    return null;
  }

  Future<bool> acceptBid(String jobId, String bidId) async {
    try {
      final response = await _dio.post('/marketplace/jobs/$jobId/accept/$bidId');
      return response.statusCode == 200;
    } catch (e) {
      print('Accept bid error: $e');
    }
    return false;
  }

  Future<bool> completeJob(String jobId, int score, String comment) async {
    try {
      final response = await _dio.post(
        '/marketplace/jobs/$jobId/complete',
        data: {'score': score, 'comment': comment},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Complete job error: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getInsights(String category) async {
    try {
      final response = await _dio.get('/marketplace/jobs/insights', queryParameters: {'category': category});
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Get insights error: $e');
    }
    return null;
  }

  Future<List<Bid>> getProviderBids() async {
    try {
      final response = await _dio.get('/marketplace/jobs/provider/bids');
      if (response.statusCode == 200) {
        final List bidsData = response.data['bids'];
        return bidsData.map((json) => Bid.fromJson(json)).toList();
      }
    } catch (e) {
      print('Get provider bids error: $e');
    }
    return [];
  }

  Future<List<Job>> getProviderJobs() async {
    try {
      final response = await _dio.get('/marketplace/jobs/provider/jobs');
      if (response.statusCode == 200) {
        final List jobsData = response.data['jobs'];
        return jobsData.map((json) => Job(
              id: json['id'],
              title: json['title'],
              description: json['description'],
              category: json['category'],
              status: _parseStatus(json['status']),
              maxBudget: (json['max_budget'] as num?)?.toDouble(),
              location: (json['lat'] != null && json['lng'] != null) 
                ? LatLng(json['lat'], json['lng']) 
                : null,
              createdAt: DateTime.parse(json['created_at']),
            )).toList();
      }
    } catch (e) {
      print('Get provider jobs error: $e');
    }
    return [];
  }

  Future<Job?> createJob({
    required String title,
    required String description,
    required String category,
    double? maxBudget,
    bool isEmergency = false,
    LatLng? location,
  }) async {
    try {
      final response = await _dio.post(
        '/marketplace/jobs/',
        data: {
          'title': title,
          'description': description,
          'category': category,
          'max_budget': maxBudget,
          'is_emergency': isEmergency,
          'lat': location?.latitude,
          'lng': location?.longitude,
        },
      );

      if (response.statusCode == 201) {
        final json = response.data;
        return Job(
          id: json['id'],
          title: title,
          description: description,
          category: category,
          status: JobStatus.published,
          maxBudget: maxBudget,
          isEmergency: isEmergency,
          location: location,
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Create job error: $e');
    }
    return null;
  }

  Future<bool> updateJobStatus(String jobId, JobStatus status) async {
    try {
      String statusStr = 'ACCEPTED';
      if (status == JobStatus.enRoute) {
        statusStr = 'EN_ROUTE';
      } else if (status == JobStatus.inProgress) {
        statusStr = 'IN_PROGRESS';
      } else if (status == JobStatus.completed) {
        statusStr = 'COMPLETED';
      } else if (status == JobStatus.published) {
        statusStr = 'PUBLISHED';
      }
      final response = await _dio.post(
        '/marketplace/jobs/$jobId/status',
        data: {'status': statusStr},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update job status error: $e');
    }
    return false;
  }

  JobStatus _parseStatus(String status) {
    switch (status) {
      case 'DRAFT': return JobStatus.draft;
      case 'PUBLISHED': return JobStatus.published;
      case 'BIDDING': return JobStatus.bidding;
      case 'ACCEPTED': return JobStatus.accepted;
      case 'EN_ROUTE': return JobStatus.enRoute;
      case 'IN_PROGRESS': return JobStatus.inProgress;
      case 'COMPLETED': return JobStatus.completed;
      default: return JobStatus.draft;
    }
  }
}
