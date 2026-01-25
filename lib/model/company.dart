import 'dart:convert';


import 'package:flutter/foundation.dart';

import 'authority.dart';
import 'companyForm.dart'; // Note: corrected casing

class Company {
  final String id;
  final String name;
  final String industry;
  final String email;
  final String phoneNumber;
  final String logoURL;
  final String localGovernment;
  final String state;
  final String address;
  final String role;
  final String fcmToken;
  final String registrationNumber;
  final String description;
  final bool isfeatured;
  final bool isActive;
  final bool isVerified;
  final bool isDeleted;
  final bool isApproved;
  final bool isRejected;
  final bool isPending;
  final bool isBlocked;
  final bool isSuspended;
  final bool isBanned;
  final bool isMuted;
  final DateTime? isMutedUntil;
  final String? isMutedBy;
  final String? isMutedFor;
  final DateTime? isMutedOn;
   List<CompanyForm>? forms; // Changed from formUrl to forms
  final DateTime? updatedAt;
  final List<dynamic> potentialtrainee;
  final List<String> pendingApplications;
  final List<String> acceptedTrainees;
  final List<String> currentTrainees;
  final List<String> completedTrainees;
  final List<String> rejectedApplications;
  final List<String> supervisors;

  // Authority relationship
  final bool isUnderAuthority;
  final String? authorityId;          // Linked authority orgId
  final String? authorityName;        // Optional (for UI display)
  final String authorityLinkStatus;   // PENDING | APPROVED | REJECTED | NONE

  final bool? wasAuthority; // Whether this company was converted from authority
  final String? originalAuthorityId; // Original authority ID if converted
  final DateTime? convertedAt; // When conversion happened
  final Authority? originalAuthority;




  Company({
    required this.id,
    required this.name,
    required this.industry,
    required this.email,
    required this.phoneNumber,
    required this.logoURL,
    required this.localGovernment,
    required this.state,
    required this.address,
    required this.role,
    required this.fcmToken,
    required this.registrationNumber,
    required this.description,
    required this.isfeatured,
    this.isActive = true,
    this.isVerified = false,
    this.isDeleted = false,
    this.isApproved = false,
    this.isRejected = false,
    this.isPending = true,
    this.isBlocked = false,
    this.isSuspended = false,
    this.isBanned = false,
    this.isMuted = false,
    this.isMutedUntil,
    this.isMutedBy,
    this.isMutedFor,
    this.isMutedOn,
    this.forms, // Updated field name
    this.updatedAt,
    this.potentialtrainee = const [],
    this.pendingApplications = const [],
    this.acceptedTrainees = const [],
    this.currentTrainees = const [],
    this.completedTrainees = const [],
    this.rejectedApplications = const [],
    this.supervisors = const [],
    // 🔽 NEW
    this.isUnderAuthority = false,
    this.authorityId,
    this.authorityName,
    this.authorityLinkStatus = "NONE",

    this.wasAuthority = false,
    this.originalAuthorityId,
    this.convertedAt,
    this.originalAuthority,
  });

  Company copyWith({
    String? id,
    String? name,
    String? industry,
    String? email,
    String? phoneNumber,
    String? logoURL,
    String? localGovernment,
    String? state,
    String? address,
    String? role,
    String? fcmToken,
    String? registrationNumber,
    String? description,
    bool? isfeatured,
    bool? isActive,
    bool? isVerified,
    bool? isDeleted,
    bool? isApproved,
    bool? isRejected,
    bool? isPending,
    bool? isBlocked,
    bool? isSuspended,
    bool? isBanned,
    bool? isMuted,
    DateTime? isMutedUntil,
    String? isMutedBy,
    String? isMutedFor,
    DateTime? isMutedOn,
    List<CompanyForm>? forms, // Updated parameter
    DateTime? updatedAt,
    List<dynamic>? potentialtrainee,
    List<String>? pendingApplications,
    List<String>? acceptedTrainees,
    List<String>? currentTrainees,
    List<String>? completedTrainees,
    List<String>? rejectedApplications,
    List<String>? supervisors,
    bool? isUnderAuthority,
    String? authorityId,
    String? authorityName,
    String? authorityLinkStatus,
    bool? wasAuthority,
    String? originalAuthorityId,
    DateTime? convertedAt,
    Authority? originalAuthority,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      logoURL: logoURL ?? this.logoURL,
      localGovernment: localGovernment ?? this.localGovernment,
      state: state ?? this.state,
      address: address ?? this.address,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      description: description ?? this.description,
      isfeatured: isfeatured ?? this.isfeatured,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isDeleted: isDeleted ?? this.isDeleted,
      isApproved: isApproved ?? this.isApproved,
      isRejected: isRejected ?? this.isRejected,
      isPending: isPending ?? this.isPending,
      isBlocked: isBlocked ?? this.isBlocked,
      isSuspended: isSuspended ?? this.isSuspended,
      isBanned: isBanned ?? this.isBanned,
      isMuted: isMuted ?? this.isMuted,
      isMutedUntil: isMutedUntil ?? this.isMutedUntil,
      isMutedBy: isMutedBy ?? this.isMutedBy,
      isMutedFor: isMutedFor ?? this.isMutedFor,
      isMutedOn: isMutedOn ?? this.isMutedOn,
      forms: forms ?? this.forms, // Updated parameter
      updatedAt: updatedAt ?? this.updatedAt,
      potentialtrainee: potentialtrainee ?? this.potentialtrainee,
      pendingApplications: pendingApplications ?? this.pendingApplications,
      acceptedTrainees: acceptedTrainees ?? this.acceptedTrainees,
      currentTrainees: currentTrainees ?? this.currentTrainees,
      completedTrainees: completedTrainees ?? this.completedTrainees,
      rejectedApplications: rejectedApplications ?? this.rejectedApplications,
      supervisors: supervisors ?? this.supervisors,
      isUnderAuthority: isUnderAuthority ?? this.isUnderAuthority,
      authorityId: authorityId ?? this.authorityId,
      authorityName: authorityName ?? this.authorityName,
      authorityLinkStatus: authorityLinkStatus ?? this.authorityLinkStatus,
      wasAuthority: wasAuthority ?? this.wasAuthority,
      originalAuthorityId: originalAuthorityId ?? this.originalAuthorityId,
      convertedAt: convertedAt ?? this.convertedAt,
      originalAuthority: originalAuthority ?? this.originalAuthority,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'industry': industry,
      'email': email,
      'phoneNumber': phoneNumber,
      'logoURL': logoURL,
      'localGovernment': localGovernment,
      'state': state,
      'address': address,
      'role': role,
      'fcmToken': fcmToken,
      'registrationNumber': registrationNumber,
      'description': description,
      'isfeatured': isfeatured,
      'isActive': isActive,
      'isVerified': isVerified,
      'isDeleted': isDeleted,
      'isApproved': isApproved,
      'isRejected': isRejected,
      'isPending': isPending,
      'isBlocked': isBlocked,
      'isSuspended': isSuspended,
      'isBanned': isBanned,
      'isMuted': isMuted,
      'isMutedUntil': isMutedUntil?.toIso8601String(),
      'isMutedBy': isMutedBy,
      'isMutedFor': isMutedFor,
      'isMutedOn': isMutedOn?.toIso8601String(),
      'forms': forms?.map((form) => form.toMap()).toList(), // Convert forms to list of maps
      'updatedAt': updatedAt?.toIso8601String(),
      'potentialtrainee': potentialtrainee,
      'pendingApplications': pendingApplications,
      'acceptedTrainees': acceptedTrainees,
      'currentTrainees': currentTrainees,
      'completedTrainees': completedTrainees,
      'rejectedApplications': rejectedApplications,
      'supervisors': supervisors,
      'isUnderAuthority': isUnderAuthority,
      'authorityId': authorityId,
      'authorityName': authorityName,
      'authorityLinkStatus': authorityLinkStatus,
      'wasAuthority': wasAuthority,
      'originalAuthorityId': originalAuthorityId,
      'convertedAt': convertedAt?.toIso8601String(),
      'originalAuthority': originalAuthority?.toMap(),
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      industry: map['industry']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      logoURL: map['logoURL']?.toString() ?? '',
      localGovernment: map['localGovernment']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      role: map['role']?.toString() ?? 'company',
      fcmToken: map['fcmToken']?.toString() ?? '',
      registrationNumber: map['registrationNumber']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      isfeatured: map['isfeatured'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      isVerified: map['isVerified'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      isApproved: map['isApproved'] as bool? ?? false,
      isRejected: map['isRejected'] as bool? ?? false,
      isPending: map['isPending'] as bool? ?? true,
      isBlocked: map['isBlocked'] as bool? ?? false,
      isSuspended: map['isSuspended'] as bool? ?? false,
      isBanned: map['isBanned'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? false,
      isMutedUntil: map['isMutedUntil'] != null
          ? DateTime.tryParse(map['isMutedUntil'].toString())
          : null,
      isMutedBy: map['isMutedBy']?.toString(),
      isMutedFor: map['isMutedFor']?.toString(),
      isMutedOn: map['isMutedOn'] != null
          ? DateTime.tryParse(map['isMutedOn'].toString())
          : null,
      forms: () {
        final formsData = map['forms'];
        final formUrlsData = map['formUrl']; // Also check formUrl field

        // First, try to parse as proper CompanyForm objects from 'forms' field
        if (formsData is List) {
          final List<CompanyForm> forms = [];
          for (final item in formsData) {
            try {
              if (item is Map<String, dynamic>) {
                forms.add(CompanyForm.fromMap(item));
              } else if (item is Map) {
                forms.add(CompanyForm.fromMap(item.cast<String, dynamic>()));
              } else if (item is String) {
                // If it's a string URL, create a CompanyForm from it
                forms.add(CompanyForm(
                  formId: "",
                  companyId: "",
                  departmentName: "",
                  uploadedAt: DateTime.now(),
                  downloadUrl: item,
                  fileName: item.split('/').last.split('?').first,
                  // Add other default fields as needed
                ));
              }
            } catch (e) {
              print('Warning: Could not parse form data: $item');
            }
          }
          if (forms.isNotEmpty) return forms;
        }

        // Second, try to parse from 'formUrl' field (array of strings)
        if (formUrlsData is List) {
          return formUrlsData.whereType<String>().map((url) {
            return CompanyForm(
              formId: "",
              departmentName: "",
              companyId: "",
              downloadUrl: url,
              fileName: url.split('/').last.split('?').first,
              uploadedAt: DateTime.now(), // Or use a default/createdAt date
              // Add other default fields
            );
          }).toList();
        }

        return null;
      }(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      potentialtrainee: (map['potentialtrainee'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      pendingApplications: List<String>.from(map['pendingApplications'] ?? []),
      acceptedTrainees: List<String>.from(map['acceptedTrainees'] ?? []),
      currentTrainees: List<String>.from(map['currentTrainees'] ?? []),
      completedTrainees: List<String>.from(map['completedTrainees'] ?? []),
      rejectedApplications: List<String>.from(map['rejectedApplications'] ?? []),
      supervisors: List<String>.from(map['supervisors'] ?? []),
      isUnderAuthority: map['isUnderAuthority'] as bool? ?? false,
      authorityId: map['authorityId']?.toString(),
      authorityName: map['authorityName']?.toString(),
      authorityLinkStatus:
      map['authorityLinkStatus']?.toString() ?? "NONE",

      wasAuthority: map['wasAuthority'] as bool? ?? false,
      originalAuthorityId: map['originalAuthorityId']?.toString(),
      convertedAt: map['convertedAt'] != null
          ? DateTime.tryParse(map['convertedAt'].toString())
          : null,
      originalAuthority: map['originalAuthority'] != null
          ? Authority.fromMap(Map<String, dynamic>.from(map['originalAuthority']))
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Company.fromJson(String source) =>
      Company.fromMap(json.decode(source));

  /// Check if this company was originally an authority
  bool get isConvertedAuthority => wasAuthority == true && originalAuthority != null;

  /// Get authority-specific data if available
  Authority? get authorityData => originalAuthority;

  /// Get linked companies from authority (if converted)
  List<String> get authorityLinkedCompanies =>
      originalAuthority?.linkedCompanies ?? [];

  /// Get authority admins (if converted)
  List<String> get authorityAdmins => originalAuthority?.admins ?? [];

  /// Get authority supervisors (if converted)
  List<String> get authoritySupervisors => originalAuthority?.supervisors ?? [];

  /// Get pending applications from authority
  List<String> get authorityPendingApplications =>
      originalAuthority?.pendingApplications ?? [];

  /// Check if has specific authority functionality
  bool hasAuthorityFeature(String feature) {
    if (!isConvertedAuthority) return false;

    switch (feature) {
      case 'canReviewApplications':
        return originalAuthority!.pendingApplications.isNotEmpty;
      case 'hasLinkedCompanies':
        return originalAuthority!.linkedCompanies.isNotEmpty;
      case 'canAutoApprove':
        return originalAuthority!.autoApproveAfterAuthority;
      case 'requirePhysicalLetter':
        return originalAuthority!.requirePhysicalLetter;
      default:
        return false;
    }
  }

  @override
  String toString() {
    return 'Company(id: $id, name: $name, industry: $industry, email: $email, phoneNumber: $phoneNumber, logoURL: $logoURL, localGovernment: $localGovernment, state: $state, address: $address, role: $role, fcmToken: $fcmToken, registrationNumber: $registrationNumber, description: $description, isfeatured: $isfeatured, isActive: $isActive, isVerified: $isVerified, isDeleted: $isDeleted, isApproved: $isApproved, isRejected: $isRejected, isPending: $isPending, isBlocked: $isBlocked, isSuspended: $isSuspended, isBanned: $isBanned, isMuted: $isMuted, isMutedUntil: $isMutedUntil, isMutedBy: $isMutedBy, isMutedFor: $isMutedFor, isMutedOn: $isMutedOn, forms: $forms, updatedAt: $updatedAt, potentialtrainee: $potentialtrainee, pendingApplications: $pendingApplications, acceptedTrainees: $acceptedTrainees, currentTrainees: $currentTrainees, completedTrainees: $completedTrainees, rejectedApplications: $rejectedApplications, supervisors: $supervisors '
        ' isUnderAuthority: $isUnderAuthority,'
        ' authorityId: $authorityId,'
        ' authorityName: $authorityName,'
        ' authorityLinkStatus: $authorityLinkStatus)'
        'wasAuthority: $wasAuthority, '
        'originalAuthorityId: $originalAuthorityId, '
        'hasAuthorityData: ${originalAuthority != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Company &&
        other.id == id &&
        other.name == name &&
        other.industry == industry &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.logoURL == logoURL &&
        other.localGovernment == localGovernment &&
        other.state == state &&
        other.address == address &&
        other.role == role &&
        other.fcmToken == fcmToken &&
        other.registrationNumber == registrationNumber &&
        other.description == description &&
        other.isfeatured == isfeatured &&
        other.isActive == isActive &&
        other.isVerified == isVerified &&
        other.isDeleted == isDeleted &&
        other.isApproved == isApproved &&
        other.isRejected == isRejected &&
        other.isPending == isPending &&
        other.isBlocked == isBlocked &&
        other.isSuspended == isSuspended &&
        other.isBanned == isBanned &&
        other.isMuted == isMuted &&
        other.isMutedUntil == isMutedUntil &&
        other.isMutedBy == isMutedBy &&
        other.isMutedFor == isMutedFor &&
        other.isMutedOn == isMutedOn &&
        listEquals(other.forms, forms) && // Use listEquals for list comparison
        other.updatedAt == updatedAt &&
        listEquals(other.potentialtrainee, potentialtrainee) &&
        listEquals(other.pendingApplications, pendingApplications) &&
        listEquals(other.acceptedTrainees, acceptedTrainees) &&
        listEquals(other.currentTrainees, currentTrainees) &&
        listEquals(other.completedTrainees, completedTrainees) &&
        listEquals(other.rejectedApplications, rejectedApplications) &&
        listEquals(other.supervisors, supervisors);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      name,
      industry,
      email,
      phoneNumber,
      logoURL,
      localGovernment,
      state,
      address,
      role,
      fcmToken,
      registrationNumber,
      description,
      isfeatured,
      isActive,
      isVerified,
      isDeleted,
      isApproved,
      isRejected,
      isPending,
      isBlocked,
      isSuspended,
      isBanned,
      isMuted,
      isMutedUntil,
      isMutedBy,
      isMutedFor,
      isMutedOn,
      forms,
      updatedAt,
      Object.hashAll(potentialtrainee),
      Object.hashAll(pendingApplications),
      Object.hashAll(acceptedTrainees),
      Object.hashAll(currentTrainees),
      Object.hashAll(completedTrainees),
      Object.hashAll(rejectedApplications),
      Object.hashAll(supervisors),
    ]);
  }

  // Helper methods for forms
  void addForm(CompanyForm form) {
    final currentForms = forms ?? [];
    forms = [...currentForms, form];
  }

  void removeForm(String formId) {
    forms?.removeWhere((form) => form.formId == formId);
  }


  CompanyForm? getFormById(String formId) {
    if (forms == null) return null;
    try {
      return forms!.firstWhere((form) => form.formId == formId);
    } catch (e) {
      return null;
    }
  }

  List<CompanyForm> getFormsByDepartment(String departmentName) {
    return forms
        ?.where((form) => form.departmentName.toLowerCase() == departmentName.toLowerCase())
        .toList() ?? [];
  }

  bool hasFormsForDepartment(String departmentName) {
    return forms?.any((form) =>
    form.departmentName.toLowerCase() == departmentName.toLowerCase()) ?? false;
  }

  int get totalFormsCount => forms?.length ?? 0;


}