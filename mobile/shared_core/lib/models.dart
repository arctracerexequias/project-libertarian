import 'package:latlong2/latlong.dart';

enum JobStatus {
  draft,
  published,
  bidding,
  accepted,
  enRoute,
  inProgress,
  completed,
  disputed,
  cancelled
}

enum RecurrenceType {
  once,
  daily,
  weekly,
  biMonthly,
  monthly
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

  // Reward related fields
  final int completedJobsCount;
  final double averageRating;
  final double totalAccumulatedAmount;
  final int rebookCount;

  // New fields
  final Establishment? establishment;
  final double walletBalance;

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
    this.completedJobsCount = 0,
    this.averageRating = 0.0,
    this.totalAccumulatedAmount = 0.0,
    this.rebookCount = 0,
    this.establishment,
    this.walletBalance = 0.0,
  });

  bool get isCoverageBoostActive => 
      coverageBoostEnabled && coverageBoostExpiry != null && coverageBoostExpiry!.isAfter(DateTime.now());
  
  bool get isRoamBoostActive => 
      roamBoostExpiry != null && roamBoostExpiry!.isAfter(DateTime.now());

  bool get isTier1Unlocked => 
      completedJobsCount >= 10 && 
      averageRating >= 4.2 && 
      totalAccumulatedAmount >= 10000;

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
          ? LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble())
          : null,
      secondaryLocation: (json['sec_lat'] != null && json['sec_lng'] != null)
          ? LatLng((json['sec_lat'] as num).toDouble(), (json['sec_lng'] as num).toDouble())
          : null,
      coverageBoostExpiry: json['coverage_boost_expiry'] != null
          ? DateTime.parse(json['coverage_boost_expiry'])
          : null,
      roamBoostExpiry: json['roam_boost_expiry'] != null
          ? DateTime.parse(json['roam_boost_expiry'])
          : null,
      coverageBoostEnabled: json['coverage_boost_enabled'] ?? false,
      completedJobsCount: json['completed_jobs_count'] ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalAccumulatedAmount: (json['total_accumulated_amount'] as num?)?.toDouble() ?? 0.0,
      rebookCount: json['rebook_count'] ?? 0,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      establishment: json['establishment'] != null ? Establishment.fromJson(json['establishment']) : null,
    );
  }
}

class Establishment {
  final String name;
  final String businessType;
  final String registrationNumber;
  final String address;

  Establishment({
    required this.name,
    required this.businessType,
    this.registrationNumber = '',
    this.address = '',
  });

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      name: json['name'] ?? '',
      businessType: json['business_type'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'business_type': businessType,
    'registration_number': registrationNumber,
    'address': address,
  };
}

class Job {
  final String id;
  final String customerId;
  final String title;
  final String description;
  final String category;
  final JobStatus status;
  final double? maxBudget;
  final LatLng? location;
  final bool isEmergency;
  final RecurrenceType recurrenceType;
  final int totalOccurrences;
  final String? parentJobId;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  Job({
    required this.id,
    required this.customerId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    this.maxBudget,
    this.location,
    this.isEmergency = false,
    this.recurrenceType = RecurrenceType.once,
    this.totalOccurrences = 1,
    this.parentJobId,
    this.scheduledAt,
    required this.createdAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      customerId: json['customer_id'] ?? '',
      title: json['title'],
      description: json['description'],
      category: json['category'],
      status: _parseStatus(json['status']),
      maxBudget: (json['max_budget'] as num?)?.toDouble(),
      isEmergency: json['is_emergency'] ?? false,
      recurrenceType: _parseRecurrence(json['recurrence_type']),
      totalOccurrences: json['total_occurrences'] ?? 1,
      parentJobId: json['parent_job_id'],
      scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at']) : null,
      location: (json['lat'] != null && json['lng'] != null) 
          ? LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static JobStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'BIDDING': return JobStatus.bidding;
      case 'PUBLISHED': return JobStatus.published;
      case 'ACCEPTED': return JobStatus.accepted;
      case 'EN_ROUTE': return JobStatus.enRoute;
      case 'IN_PROGRESS': return JobStatus.inProgress;
      case 'COMPLETED': return JobStatus.completed;
      case 'DISPUTED': return JobStatus.disputed;
      case 'CANCELLED': return JobStatus.cancelled;
      default: return JobStatus.draft;
    }
  }

  static RecurrenceType _parseRecurrence(String? type) {
    switch (type?.toUpperCase()) {
      case 'DAILY': return RecurrenceType.daily;
      case 'WEEKLY': return RecurrenceType.weekly;
      case 'BI_MONTHLY': return RecurrenceType.biMonthly;
      case 'MONTHLY': return RecurrenceType.monthly;
      default: return RecurrenceType.once;
    }
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
  final String declineReason;
  final double counterAmount;
  final String counterBy;
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
    this.declineReason = '',
    this.counterAmount = 0.0,
    this.counterBy = '',
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
      declineReason: json['decline_reason'] ?? '',
      counterAmount: (json['counter_amount'] as num?)?.toDouble() ?? 0.0,
      counterBy: json['counter_by'] ?? '',
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
