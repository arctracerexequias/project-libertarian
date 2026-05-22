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

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.isVerified = false,
    this.bio = '',
    this.skills = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      isVerified: json['is_verified'] ?? false,
      bio: json['bio'] ?? '',
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
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
      jobId: json['job_id'],
      senderId: json['sender_id'],
      content: json['content'],
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'sender_id': senderId,
    'content': content,
  };
}
