import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'network_service.dart';
import 'models.dart';

class MarketplaceService {
  final Dio _dio = NetworkService().dio;

  MarketplaceService();

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
        return jobsData.map((json) => Job.fromJson(json)).toList();
      }
    } catch (e) {
      print('Get jobs error: $e');
    }
    return [];
  }

  Future<Job?> getJob(String jobId) async {
    try {
      final response = await _dio.get('/marketplace/jobs/$jobId');
      if (response.statusCode == 200) {
        return Job.fromJson(response.data);
      }
    } catch (e) {
      print('Get job error: $e');
    }
    return null;
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
          providerName: '',
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

  Future<bool> rejectBid(String jobId, String bidId, {String? reason}) async {
    try {
      final response = await _dio.post(
        '/marketplace/jobs/$jobId/reject/$bidId',
        data: {'reason': reason},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Reject bid error: $e');
    }
    return false;
  }

  Future<bool> counterOffer(String bidId, double amount, {String? reason}) async {
    try {
      final response = await _dio.post(
        '/marketplace/jobs/bids/$bidId/counter',
        data: {'amount': amount, 'reason': reason},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Counter bid error: $e');
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
        return jobsData.map((json) => Job.fromJson(json)).toList();
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
    RecurrenceType recurrenceType = RecurrenceType.once,
    int totalOccurrences = 1,
    String? parentJobId,
    DateTime? scheduledAt,
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
          'lat': location?.latitude ?? 0.0,
          'lng': location?.longitude ?? 0.0,
          'recurrence_type': recurrenceType.name.toUpperCase(),
          'total_occurrences': totalOccurrences,
          'parent_job_id': parentJobId,
          'scheduled_at': scheduledAt?.toIso8601String(),
        },
      );

      if (response.statusCode == 201) {
        final json = response.data;
        return Job.fromJson(json);
      } else {
        print('Create job failed with status: ${response.statusCode}, data: ${response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        print('Create job DioError: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        print('Create job error: $e');
      }
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

  Future<bool> cancelJob(String jobId) async {
    try {
      final response = await _dio.post('/marketplace/jobs/$jobId/cancel');
      return response.statusCode == 200;
    } catch (e) {
      print('Cancel job error: $e');
    }
    return false;
  }
}
