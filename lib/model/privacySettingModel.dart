// models/privacy_settings_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final bool twoFactorAuth;
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
  });

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
      updatedBy: FirebaseAuth.instance.currentUser?.uid,
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
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    };
  }

  // Create from Firestore document
  factory PrivacySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

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
    );
  }
}