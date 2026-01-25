import 'dart:convert';
import 'package:flutter/foundation.dart';

class Authority {
  final String id;
  final String name;
  final String email;
  final String? contactPerson;
  final String? phoneNumber;
  final String? logoURL;
  final String? address;
  final String? state;
  final String? localGovernment;
  final String? registrationNumber;
  final String? description;

  // Status fields
  final bool isActive;
  final bool isVerified;
  final bool isApproved;
  final bool isBlocked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Linked companies (IDs)
  final List<String> linkedCompanies;

  // Applications for review
  final List<String> pendingApplications;
  final List<String> approvedApplications;
  final List<String> rejectedApplications;

  // Administrators for this authority
  final List<String> admins;
  final List<String> supervisors;

  // Communication
  final String fcmToken;
  final List<String> notificationTokens;

  // Settings
  final bool autoApproveAfterAuthority;
  final int maxCompaniesAllowed;
  final int maxApplicationsPerBatch;
  final bool requirePhysicalLetter;
  final String? letterTemplateUrl;

  // Statistics (could be computed, but cached for performance)
  final int totalApplicationsReviewed;
  final int currentPendingCount;
  final double averageProcessingTimeDays;

  final bool isConvertedToCompany;
  final String? convertedToCompanyId;
  final String? convertedBy;
  final DateTime? convertedAt;
  final bool isArchived; // Keep authority data but mark as archived

  Authority({
    required this.id,
    required this.name,
    required this.email,
    this.contactPerson,
    this.phoneNumber,
    this.logoURL,
    this.address,
    this.state,
    this.localGovernment,
    this.registrationNumber,
    this.description,

    // Status with defaults
    this.isActive = true,
    this.isVerified = false,
    this.isApproved = false,
    this.isBlocked = false,
    this.createdAt,
    this.updatedAt,

    // Lists with defaults
    this.linkedCompanies = const [],
    this.pendingApplications = const [],
    this.approvedApplications = const [],
    this.rejectedApplications = const [],
    this.admins = const [],
    this.supervisors = const [],

    // Communication defaults
    this.fcmToken = '',
    this.notificationTokens = const [],

    // Settings defaults
    this.autoApproveAfterAuthority = false,
    this.maxCompaniesAllowed = 50,
    this.maxApplicationsPerBatch = 100,
    this.requirePhysicalLetter = false,
    this.letterTemplateUrl,

    // Statistics defaults
    this.totalApplicationsReviewed = 0,
    this.currentPendingCount = 0,
    this.averageProcessingTimeDays = 0.0,

    this.isConvertedToCompany = false,
    this.convertedToCompanyId,
    this.convertedBy,
    this.convertedAt,
    this.isArchived = false,
  });

  // Copy with method
  // Update copyWith method in Authority class:
  Authority copyWith({
    String? id,
    String? name,
    String? email,
    String? contactPerson,
    String? phoneNumber,
    String? logoURL,
    String? address,
    String? state,
    String? localGovernment,
    String? registrationNumber,
    String? description,
    bool? isActive,
    bool? isVerified,
    bool? isApproved,
    bool? isBlocked,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? linkedCompanies,
    List<String>? pendingApplications,
    List<String>? approvedApplications,
    List<String>? rejectedApplications,
    List<String>? admins,
    List<String>? supervisors,
    String? fcmToken,
    List<String>? notificationTokens,
    bool? autoApproveAfterAuthority,
    int? maxCompaniesAllowed,
    int? maxApplicationsPerBatch,
    bool? requirePhysicalLetter,
    String? letterTemplateUrl,
    int? totalApplicationsReviewed,
    int? currentPendingCount,
    double? averageProcessingTimeDays,
    // Add conversion fields
    bool? isConvertedToCompany,
    String? convertedToCompanyId,
    String? convertedBy,
    DateTime? convertedAt,
    bool? isArchived,
  }) {
    return Authority(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      contactPerson: contactPerson ?? this.contactPerson,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      logoURL: logoURL ?? this.logoURL,
      address: address ?? this.address,
      state: state ?? this.state,
      localGovernment: localGovernment ?? this.localGovernment,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isApproved: isApproved ?? this.isApproved,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      linkedCompanies: linkedCompanies ?? this.linkedCompanies,
      pendingApplications: pendingApplications ?? this.pendingApplications,
      approvedApplications: approvedApplications ?? this.approvedApplications,
      rejectedApplications: rejectedApplications ?? this.rejectedApplications,
      admins: admins ?? this.admins,
      supervisors: supervisors ?? this.supervisors,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationTokens: notificationTokens ?? this.notificationTokens,
      autoApproveAfterAuthority: autoApproveAfterAuthority ?? this.autoApproveAfterAuthority,
      maxCompaniesAllowed: maxCompaniesAllowed ?? this.maxCompaniesAllowed,
      maxApplicationsPerBatch: maxApplicationsPerBatch ?? this.maxApplicationsPerBatch,
      requirePhysicalLetter: requirePhysicalLetter ?? this.requirePhysicalLetter,
      letterTemplateUrl: letterTemplateUrl ?? this.letterTemplateUrl,
      totalApplicationsReviewed: totalApplicationsReviewed ?? this.totalApplicationsReviewed,
      currentPendingCount: currentPendingCount ?? this.currentPendingCount,
      averageProcessingTimeDays: averageProcessingTimeDays ?? this.averageProcessingTimeDays,
      // Add conversion fields
      isConvertedToCompany: isConvertedToCompany ?? this.isConvertedToCompany,
      convertedToCompanyId: convertedToCompanyId ?? this.convertedToCompanyId,
      convertedBy: convertedBy ?? this.convertedBy,
      convertedAt: convertedAt ?? this.convertedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'contactPerson': contactPerson,
      'phoneNumber': phoneNumber,
      'logoURL': logoURL,
      'address': address,
      'state': state,
      'localGovernment': localGovernment,
      'registrationNumber': registrationNumber,
      'description': description,
      'isActive': isActive,
      'isVerified': isVerified,
      'isApproved': isApproved,
      'isBlocked': isBlocked,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'linkedCompanies': linkedCompanies,
      'pendingApplications': pendingApplications,
      'approvedApplications': approvedApplications,
      'rejectedApplications': rejectedApplications,
      'admins': admins,
      'supervisors': supervisors,
      'fcmToken': fcmToken,
      'notificationTokens': notificationTokens,
      'autoApproveAfterAuthority': autoApproveAfterAuthority,
      'maxCompaniesAllowed': maxCompaniesAllowed,
      'maxApplicationsPerBatch': maxApplicationsPerBatch,
      'requirePhysicalLetter': requirePhysicalLetter,
      'letterTemplateUrl': letterTemplateUrl,
      'totalApplicationsReviewed': totalApplicationsReviewed,
      'currentPendingCount': currentPendingCount,
      'averageProcessingTimeDays': averageProcessingTimeDays,
      'isConvertedToCompany': isConvertedToCompany,
      'convertedToCompanyId': convertedToCompanyId,
      'convertedBy': convertedBy,
      'convertedAt': convertedAt?.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  // Factory constructor from Map
  factory Authority.fromMap(Map<String, dynamic> map) {
    return Authority(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      contactPerson: map['contactPerson']?.toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      logoURL: map['logoURL']?.toString(),
      address: map['address']?.toString(),
      state: map['state']?.toString(),
      localGovernment: map['localGovernment']?.toString(),
      registrationNumber: map['registrationNumber']?.toString(),
      description: map['description']?.toString(),
      isActive: map['isActive'] as bool? ?? true,
      isVerified: map['isVerified'] as bool? ?? false,
      isApproved: map['isApproved'] as bool? ?? false,
      isBlocked: map['isBlocked'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      linkedCompanies: List<String>.from(map['linkedCompanies'] ?? []),
      pendingApplications: List<String>.from(map['pendingApplications'] ?? []),
      approvedApplications: List<String>.from(map['approvedApplications'] ?? []),
      rejectedApplications: List<String>.from(map['rejectedApplications'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      supervisors: List<String>.from(map['supervisors'] ?? []),
      fcmToken: map['fcmToken']?.toString() ?? '',
      notificationTokens: List<String>.from(map['notificationTokens'] ?? []),
      autoApproveAfterAuthority: map['autoApproveAfterAuthority'] as bool? ?? false,
      maxCompaniesAllowed: (map['maxCompaniesAllowed'] as num?)?.toInt() ?? 50,
      maxApplicationsPerBatch: (map['maxApplicationsPerBatch'] as num?)?.toInt() ?? 100,
      requirePhysicalLetter: map['requirePhysicalLetter'] as bool? ?? false,
      letterTemplateUrl: map['letterTemplateUrl']?.toString(),
      totalApplicationsReviewed: (map['totalApplicationsReviewed'] as num?)?.toInt() ?? 0,
      currentPendingCount: (map['currentPendingCount'] as num?)?.toInt() ?? 0,
      averageProcessingTimeDays: (map['averageProcessingTimeDays'] as num?)?.toDouble() ?? 0.0,

      isConvertedToCompany: map['isConvertedToCompany'] as bool? ?? false,
      convertedToCompanyId: map['convertedToCompanyId']?.toString(),
      convertedBy: map['convertedBy']?.toString(),
      convertedAt: map['convertedAt'] != null
          ? DateTime.tryParse(map['convertedAt'].toString())
          : null,
      isArchived: map['isArchived'] as bool? ?? false,
    );
  }

  // Convert to JSON
  String toJson() => json.encode(toMap());

  // Factory constructor from JSON
  factory Authority.fromJson(String source) =>
      Authority.fromMap(json.decode(source));

  // Helper methods
  bool hasLinkedCompany(String companyId) {
    return linkedCompanies.contains(companyId);
  }

  bool canAddMoreCompanies() {
    return linkedCompanies.length < maxCompaniesAllowed;
  }

  bool hasPendingApplication(String applicationId) {
    return pendingApplications.contains(applicationId);
  }

  void addLinkedCompany(String companyId) {
    if (!linkedCompanies.contains(companyId) && canAddMoreCompanies()) {
      linkedCompanies.add(companyId);
    }
  }

  void removeLinkedCompany(String companyId) {
    linkedCompanies.remove(companyId);
  }

  void addPendingApplication(String applicationId) {
    if (!pendingApplications.contains(applicationId)) {
      pendingApplications.add(applicationId);
    }
  }

  void removePendingApplication(String applicationId) {
    pendingApplications.remove(applicationId);
  }

  void addApprovedApplication(String applicationId) {
    if (!approvedApplications.contains(applicationId)) {
      approvedApplications.add(applicationId);
    }
  }

  void addRejectedApplication(String applicationId) {
    if (!rejectedApplications.contains(applicationId)) {
      rejectedApplications.add(applicationId);
    }
  }

  void addAdmin(String adminId) {
    if (!admins.contains(adminId)) {
      admins.add(adminId);
    }
  }

  void removeAdmin(String adminId) {
    admins.remove(adminId);
  }

  // Statistics helper
  double get approvalRate {
    if (totalApplicationsReviewed == 0) return 0.0;
    return approvedApplications.length / totalApplicationsReviewed * 100;
  }

  int get totalProcessedApplications {
    return approvedApplications.length + rejectedApplications.length;
  }

  bool get hasReachedCompanyLimit {
    return linkedCompanies.length >= maxCompaniesAllowed;
  }

  // Override toString
  @override
  String toString() {
    return 'Authority(id: $id, name: $name, email: $email, linkedCompanies: ${linkedCompanies.length}, pendingApps: ${pendingApplications.length})';
  }

  // Override == and hashCode
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Authority &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, isActive);
  }
}

// Authority Types (if needed)
enum AuthorityType {
  MINISTRY,
  DEPARTMENT,
  AGENCY,
  PARASTATAL,
  LOCAL_GOVERNMENT,
  STATE_GOVERNMENT,
  FEDERAL,
  OTHER,
}

// Authority Approval Decision
class AuthorityDecision {
  final String authorityId;
  final String applicationId;
  final bool isApproved;
  final String? remarks;
  final DateTime decisionDate;
  final String? letterUrl;
  final String? approvedBy; // Admin ID who made decision

  AuthorityDecision({
    required this.authorityId,
    required this.applicationId,
    required this.isApproved,
    this.remarks,
    required this.decisionDate,
    this.letterUrl,
    this.approvedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorityId': authorityId,
      'applicationId': applicationId,
      'isApproved': isApproved,
      'remarks': remarks,
      'decisionDate': decisionDate.toIso8601String(),
      'letterUrl': letterUrl,
      'approvedBy': approvedBy,
    };
  }

  factory AuthorityDecision.fromMap(Map<String, dynamic> map) {
    return AuthorityDecision(
      authorityId: map['authorityId'] as String,
      applicationId: map['applicationId'] as String,
      isApproved: map['isApproved'] as bool,
      remarks: map['remarks'] as String?,
      decisionDate: DateTime.parse(map['decisionDate'] as String),
      letterUrl: map['letterUrl'] as String?,
      approvedBy: map['approvedBy'] as String?,
    );
  }
}