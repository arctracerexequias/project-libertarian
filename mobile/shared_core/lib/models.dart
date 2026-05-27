import 'package:latlong2/latlong.dart';

enum JobStatus {
  draft,
  published,
  bidding,
  accepted,
  enRoute,
  inProgress,
  completed,
  disputed
}

class Job {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? subcategory;
  final JobStatus status;
  final double? maxBudget;
  final bool isEmergency;
  final LatLng? location;
  final DateTime createdAt;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.subcategory,
    required this.status,
    this.maxBudget,
    this.isEmergency = false,
    this.location,
    required this.createdAt,
  });
}

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isVerified;
  final String bio;
  final List<String> skills;
  
  // Boost related fields
  final LatLng? primaryLocation;
  final LatLng? secondaryLocation;
  final DateTime? coverageBoostExpiry;
  final DateTime? roamBoostExpiry;
  final bool coverageBoostEnabled;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.isVerified = false,
    this.bio = '',
    this.skills = const [],
    this.primaryLocation,
    this.secondaryLocation,
    this.coverageBoostExpiry,
    this.roamBoostExpiry,
    this.coverageBoostEnabled = false,
  });

  bool get isCoverageBoostActive => 
      coverageBoostEnabled && coverageBoostExpiry != null && coverageBoostExpiry!.isAfter(DateTime.now());
  
  bool get isRoamBoostActive => 
      roamBoostExpiry != null && roamBoostExpiry!.isAfter(DateTime.now());

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      isVerified: json['is_verified'] ?? false,
      bio: json['bio'] ?? '',
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
      primaryLocation: (json['lat'] != null && json['lng'] != null)
          ? LatLng(json['lat'], json['lng'])
          : null,
      secondaryLocation: (json['sec_lat'] != null && json['sec_lng'] != null)
          ? LatLng(json['sec_lat'], json['sec_lng'])
          : null,
      coverageBoostExpiry: json['coverage_boost_expiry'] != null
          ? DateTime.parse(json['coverage_boost_expiry'])
          : null,
      roamBoostExpiry: json['roam_boost_expiry'] != null
          ? DateTime.parse(json['roam_boost_expiry'])
          : null,
      coverageBoostEnabled: json['coverage_boost_enabled'] ?? false,
    );
  }
}

class Bid {
  final String id;
  final String jobId;
  final String providerId;
  final double amount;
  final String estimatedTime;
  final String message;
  final String status;
  final double providerRating;
  final bool providerVerified;
  final String providerName;
  final DateTime createdAt;

  Bid({
    required this.id,
    required this.jobId,
    required this.providerId,
    required this.amount,
    required this.estimatedTime,
    required this.message,
    required this.status,
    required this.providerRating,
    this.providerVerified = false,
    this.providerName = '',
    required this.createdAt,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id'],
      jobId: json['job_id'],
      providerId: json['provider_id'],
      amount: (json['amount'] as num).toDouble(),
      estimatedTime: json['estimated_time'],
      message: json['message'] ?? '',
      status: json['status'],
      providerRating: (json['provider_rating'] as num?)?.toDouble() ?? 5.0,
      providerVerified: json['provider_verified'] ?? false,
      providerName: json['provider_name'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ChatMessage {
  final String jobId;
  final String senderId;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.jobId,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      jobId: json['job_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      timestamp: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'sender_id': senderId,
    'content': content,
  };
}
