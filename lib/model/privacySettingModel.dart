// models/privacy_settings_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../itc_logic/idservice/globalIdService.dart';

// Add enum for 2FA method
enum TwoFactorMethod {
  sms,
  password,
  none,
}

class PrivacySettings {
  // Profile Privacy
  final bool profileVisibility;
  final bool showEmail;
  final bool showPhoneNumber;
  final bool showLocation;
  final bool showCompanyInfo;

  // Data Sharing
  final bool shareAnalytics;
  final bool shareWithPartners;
  final bool personalizedAds;

  // Account Security
  bool twoFactorAuth;
  final bool loginAlerts;
  final bool deviceManagement;
  final bool sessionTimeout;
  final int sessionTimeoutMinutes;

  // Data Management
  final bool dataBackup;
  final bool autoDeleteData;
  final int autoDeleteDays;

  // Content Privacy
  final bool hideFromSearch;
  final bool blockUnknownUsers;
  final bool messagePrivacy;

  // Activity Privacy
  final bool showOnlineStatus;
  final bool showLastSeen;
  final bool showActivityStatus;

  // Metadata
  final DateTime? lastUpdated;
  final String? updatedBy;

  // Two-Factor Authentication
  final List<EnrolledFactor>? enrolledFactors; // For SMS 2FA
  final DateTime? twoFactorEnabledAt;
  final TwoFactorMethod twoFactorMethod; // New: tracks which method is used

  PrivacySettings({
    // Profile Privacy
    required this.profileVisibility,
    required this.showEmail,
    required this.showPhoneNumber,
    required this.showLocation,
    required this.showCompanyInfo,

    // Data Sharing
    required this.shareAnalytics,
    required this.shareWithPartners,
    required this.personalizedAds,

    // Account Security
    required this.twoFactorAuth,
    required this.loginAlerts,
    required this.deviceManagement,
    required this.sessionTimeout,
    required this.sessionTimeoutMinutes,

    // Data Management
    required this.dataBackup,
    required this.autoDeleteData,
    required this.autoDeleteDays,

    // Content Privacy
    required this.hideFromSearch,
    required this.blockUnknownUsers,
    required this.messagePrivacy,

    // Activity Privacy
    required this.showOnlineStatus,
    required this.showLastSeen,
    required this.showActivityStatus,

    // Metadata
    this.lastUpdated,
    this.updatedBy,

    this.enrolledFactors,
    this.twoFactorEnabledAt,
    this.twoFactorMethod = TwoFactorMethod.none, // Default to none
  });

  // Helper method to check if 2FA is actually enrolled (SMS)
  bool get isSmsTwoFactorEnrolled => enrolledFactors != null && enrolledFactors!.isNotEmpty;

  // Helper method to check if password 2FA is enabled (from Firestore)
  // This would be stored separately in your twoFactorPasswords collection
  bool isPasswordTwoFactorEnabled(String userId) {
    // This should check the twoFactorPasswords collection
    // For now, return false - will be checked by service
    return twoFactorAuth && twoFactorMethod == TwoFactorMethod.password;
  }

  // Helper method to get the active 2FA method
  TwoFactorMethod get activeTwoFactorMethod {
    if (!twoFactorAuth) return TwoFactorMethod.none;
    return twoFactorMethod;
  }

  // Helper method to check if ANY 2FA is enrolled
  bool get isAnyTwoFactorEnrolled {
    if (!twoFactorAuth) return false;
    return twoFactorMethod != TwoFactorMethod.none;
  }

  // Check if user should be prompted to enroll 2FA
  bool shouldEnrollTwoFactor(String? viewerId, String profileOwnerId) {
    // Only the profile owner can see/enroll 2FA
    if (viewerId != null && viewerId == profileOwnerId) {
      return twoFactorAuth && !isAnyTwoFactorEnrolled;
    }
    return false;
  }

  // Check if 2FA is required for login
  bool isTwoFactorRequired(String? viewerId, String profileOwnerId) {
    if (viewerId != null && viewerId == profileOwnerId) {
      return twoFactorAuth && isAnyTwoFactorEnrolled;
    }
    return false;
  }

  // Create default settings
  factory PrivacySettings.defaultSettings() {
    return PrivacySettings(
      profileVisibility: true,
      showEmail: true,
      showPhoneNumber: false,
      showLocation: false,
      showCompanyInfo: true,
      shareAnalytics: true,
      shareWithPartners: false,
      personalizedAds: true,
      twoFactorAuth: false,
      loginAlerts: true,
      deviceManagement: true,
      sessionTimeout: false,
      sessionTimeoutMinutes: 30,
      dataBackup: true,
      autoDeleteData: false,
      autoDeleteDays: 90,
      hideFromSearch: false,
      blockUnknownUsers: true,
      messagePrivacy: true,
      showOnlineStatus: true,
      showLastSeen: true,
      showActivityStatus: true,
      lastUpdated: DateTime.now(),
      updatedBy: GlobalIdService.firestoreId,
      twoFactorMethod: TwoFactorMethod.none,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      // Profile Privacy
      'profileVisibility': profileVisibility,
      'showEmail': showEmail,
      'showPhoneNumber': showPhoneNumber,
      'showLocation': showLocation,
      'showCompanyInfo': showCompanyInfo,

      // Data Sharing
      'shareAnalytics': shareAnalytics,
      'shareWithPartners': shareWithPartners,
      'personalizedAds': personalizedAds,

      // Account Security
      'twoFactorAuth': twoFactorAuth,
      'twoFactorMethod': twoFactorMethod.name, // Store as int
      'loginAlerts': loginAlerts,
      'deviceManagement': deviceManagement,
      'sessionTimeout': sessionTimeout,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,

      // Data Management
      'dataBackup': dataBackup,
      'autoDeleteData': autoDeleteData,
      'autoDeleteDays': autoDeleteDays,

      // Content Privacy
      'hideFromSearch': hideFromSearch,
      'blockUnknownUsers': blockUnknownUsers,
      'messagePrivacy': messagePrivacy,

      // Activity Privacy
      'showOnlineStatus': showOnlineStatus,
      'showLastSeen': showLastSeen,
      'showActivityStatus': showActivityStatus,

      // Metadata
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': GlobalIdService.firestoreId,
    };
  }

  // Create from Firestore document
  factory PrivacySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse enrolled factors if present
    List<EnrolledFactor>? enrolledFactors;
    if (data['enrolledFactors'] != null) {
      enrolledFactors = (data['enrolledFactors'] as List)
          .map((factor) => EnrolledFactor.fromJson(factor))
          .toList();
    }

    // Parse two factor method - FIXED for String values
    TwoFactorMethod twoFactorMethod = TwoFactorMethod.none;
    if (data['twoFactorMethod'] != null) {
      final methodValue = data['twoFactorMethod'];

      // Handle both String and int for backward compatibility
      if (methodValue is String) {
        // New format: string value ("sms", "password", "none")
        twoFactorMethod = TwoFactorMethod.values.firstWhere(
              (e) => e.name == methodValue,
          orElse: () => TwoFactorMethod.none,
        );
      } else if (methodValue is int) {
        // Old format: integer index (0, 1, 2)
        twoFactorMethod = TwoFactorMethod.values[methodValue];
      }
    }

    return PrivacySettings(
      profileVisibility: data['profileVisibility'] ?? true,
      showEmail: data['showEmail'] ?? true,
      showPhoneNumber: data['showPhoneNumber'] ?? false,
      showLocation: data['showLocation'] ?? false,
      showCompanyInfo: data['showCompanyInfo'] ?? true,
      shareAnalytics: data['shareAnalytics'] ?? true,
      shareWithPartners: data['shareWithPartners'] ?? false,
      personalizedAds: data['personalizedAds'] ?? true,
      twoFactorAuth: data['twoFactorAuth'] ?? false,
      loginAlerts: data['loginAlerts'] ?? true,
      deviceManagement: data['deviceManagement'] ?? true,
      sessionTimeout: data['sessionTimeout'] ?? false,
      sessionTimeoutMinutes: data['sessionTimeoutMinutes'] ?? 30,
      dataBackup: data['dataBackup'] ?? true,
      autoDeleteData: data['autoDeleteData'] ?? false,
      autoDeleteDays: data['autoDeleteDays'] ?? 90,
      hideFromSearch: data['hideFromSearch'] ?? false,
      blockUnknownUsers: data['blockUnknownUsers'] ?? true,
      messagePrivacy: data['messagePrivacy'] ?? true,
      showOnlineStatus: data['showOnlineStatus'] ?? true,
      showLastSeen: data['showLastSeen'] ?? true,
      showActivityStatus: data['showActivityStatus'] ?? true,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
      enrolledFactors: enrolledFactors,
      twoFactorEnabledAt: (data['twoFactorEnabledAt'] as Timestamp?)?.toDate(),
      twoFactorMethod: twoFactorMethod,
    );
  }
  // Create a copy with updated values
  PrivacySettings copyWith({
    bool? profileVisibility,
    bool? showEmail,
    bool? showPhoneNumber,
    bool? showLocation,
    bool? showCompanyInfo,
    bool? shareAnalytics,
    bool? shareWithPartners,
    bool? personalizedAds,
    bool? twoFactorAuth,
    bool? loginAlerts,
    bool? deviceManagement,
    bool? sessionTimeout,
    int? sessionTimeoutMinutes,
    bool? dataBackup,
    bool? autoDeleteData,
    int? autoDeleteDays,
    bool? hideFromSearch,
    bool? blockUnknownUsers,
    bool? messagePrivacy,
    bool? showOnlineStatus,
    bool? showLastSeen,
    bool? showActivityStatus,
    DateTime? lastUpdated,
    String? updatedBy,
    TwoFactorMethod? twoFactorMethod,
  }) {
    return PrivacySettings(
      profileVisibility: profileVisibility ?? this.profileVisibility,
      showEmail: showEmail ?? this.showEmail,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      showLocation: showLocation ?? this.showLocation,
      showCompanyInfo: showCompanyInfo ?? this.showCompanyInfo,
      shareAnalytics: shareAnalytics ?? this.shareAnalytics,
      shareWithPartners: shareWithPartners ?? this.shareWithPartners,
      personalizedAds: personalizedAds ?? this.personalizedAds,
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      loginAlerts: loginAlerts ?? this.loginAlerts,
      deviceManagement: deviceManagement ?? this.deviceManagement,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      dataBackup: dataBackup ?? this.dataBackup,
      autoDeleteData: autoDeleteData ?? this.autoDeleteData,
      autoDeleteDays: autoDeleteDays ?? this.autoDeleteDays,
      hideFromSearch: hideFromSearch ?? this.hideFromSearch,
      blockUnknownUsers: blockUnknownUsers ?? this.blockUnknownUsers,
      messagePrivacy: messagePrivacy ?? this.messagePrivacy,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showLastSeen: showLastSeen ?? this.showLastSeen,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
      twoFactorMethod: twoFactorMethod ?? this.twoFactorMethod,
    );
  }

  // Helper method to check if email should be shown to a viewer
  bool shouldShowEmail(String? viewerId, String profileOwnerId) {
    if (viewerId != null && viewerId == profileOwnerId) {
      return true;
    }
    return showEmail;
  }

  // Helper method to check if phone number should be shown to a viewer
  bool shouldShowPhoneNumber(String? viewerId, String profileOwnerId) {
    if (viewerId != null && viewerId == profileOwnerId) {
      return true;
    }
    return showPhoneNumber;
  }

  // Helper method to check if location should be shown to a viewer
  bool shouldShowLocation(String? viewerId, String profileOwnerId) {
    if (viewerId != null && viewerId == profileOwnerId) {
      return true;
    }
    return showLocation;
  }

  // Helper method to check if company info should be shown to a viewer
  bool shouldShowCompanyInfo(String? viewerId, String profileOwnerId) {
    if (viewerId != null && viewerId == profileOwnerId) {
      return true;
    }
    return showCompanyInfo;
  }

  // Helper method to check if profile is visible to a viewer
  bool shouldShowProfile(String? viewerId, String profileOwnerId) {
    if (viewerId != null && viewerId == profileOwnerId) {
      return true;
    }
    return profileVisibility;
  }

  // Helper method to get all visible contact information
  Map<String, bool> getVisibleContactInfo(String? viewerId, String profileOwnerId) {
    return {
      'email': shouldShowEmail(viewerId, profileOwnerId),
      'phone': shouldShowPhoneNumber(viewerId, profileOwnerId),
      'location': shouldShowLocation(viewerId, profileOwnerId),
      'companyInfo': shouldShowCompanyInfo(viewerId, profileOwnerId),
    };
  }

  // Helper method to check if ANY contact info should be shown
  bool hasAnyVisibleContactInfo(String? viewerId, String profileOwnerId) {
    return shouldShowEmail(viewerId, profileOwnerId) ||
        shouldShowPhoneNumber(viewerId, profileOwnerId) ||
        shouldShowLocation(viewerId, profileOwnerId);
  }

  // Helper method to check if ANY profile info should be shown
  bool hasAnyVisibleProfileInfo(String? viewerId, String profileOwnerId) {
    return shouldShowProfile(viewerId, profileOwnerId) ||
        shouldShowCompanyInfo(viewerId, profileOwnerId);
  }
}

class EnrolledFactor {
  final String uid;
  final String phoneNumber;
  final String displayName;
  final DateTime enrollmentTime;
  final String factorId; // 'phone' for SMS

  EnrolledFactor({
    required this.uid,
    required this.phoneNumber,
    required this.displayName,
    required this.enrollmentTime,
    required this.factorId,
  });

  factory EnrolledFactor.fromJson(Map<String, dynamic> json) {
    return EnrolledFactor(
      uid: json['uid'],
      phoneNumber: json['phoneNumber'],
      displayName: json['displayName'] ?? '',
      enrollmentTime: DateTime.parse(json['enrollmentTime']),
      factorId: json['factorId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'phoneNumber': phoneNumber,
    'displayName': displayName,
    'enrollmentTime': enrollmentTime.toIso8601String(),
    'factorId': factorId,
  };
}