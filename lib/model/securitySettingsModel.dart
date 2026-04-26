// models/security_settings_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../itc_logic/idservice/globalIdService.dart';

class SecuritySettings {
  // Authentication Security
   bool twoFactorAuth;
   bool biometricLogin;
   bool rememberMe;
   int sessionTimeoutMinutes;

  // Password Security
   bool requireStrongPassword;
   bool passwordExpiry;
   int passwordExpiryDays;
   bool preventPasswordReuse;
   int passwordHistoryCount;

  // Login Security
   bool loginAlerts;
   bool newDeviceAlerts;
   bool failedLoginAlerts;
   int maxFailedAttempts;
   bool lockAfterFailedAttempts;
   int lockDurationMinutes;

  // Session Management
   bool singleSessionOnly;
   bool sessionTimeout;
   bool autoLogoutOnInactivity;
   int inactivityTimeoutMinutes;

  // Device Management
   bool deviceManagement;
   bool allowMultipleDevices;
   int maxDevicesAllowed;

  // IP & Location Security
   bool ipWhitelist;
   List<String> allowedIps;
   bool locationRestriction;
   List<String> allowedCountries;

  // Data Security
   bool encryptData;
   bool backupData;
   bool autoBackup;
   int backupFrequencyDays;

  // Metadata
   DateTime? lastUpdated;
   String? updatedBy;

  SecuritySettings({
    // Authentication Security
    required this.twoFactorAuth,
    required this.biometricLogin,
    required this.rememberMe,
    required this.sessionTimeoutMinutes,

    // Password Security
    required this.requireStrongPassword,
    required this.passwordExpiry,
    required this.passwordExpiryDays,
    required this.preventPasswordReuse,
    required this.passwordHistoryCount,

    // Login Security
    required this.loginAlerts,
    required this.newDeviceAlerts,
    required this.failedLoginAlerts,
    required this.maxFailedAttempts,
    required this.lockAfterFailedAttempts,
    required this.lockDurationMinutes,

    // Session Management
    required this.singleSessionOnly,
    required this.sessionTimeout,
    required this.autoLogoutOnInactivity,
    required this.inactivityTimeoutMinutes,

    // Device Management
    required this.deviceManagement,
    required this.allowMultipleDevices,
    required this.maxDevicesAllowed,

    // IP & Location Security
    required this.ipWhitelist,
    required this.allowedIps,
    required this.locationRestriction,
    required this.allowedCountries,

    // Data Security
    required this.encryptData,
    required this.backupData,
    required this.autoBackup,
    required this.backupFrequencyDays,

    // Metadata
    this.lastUpdated,
    this.updatedBy,
  });

  // Create default settings
  factory SecuritySettings.defaultSettings() {
    return SecuritySettings(
      twoFactorAuth: false,
      biometricLogin: false,
      rememberMe: true,
      sessionTimeoutMinutes: 30,
      requireStrongPassword: true,
      passwordExpiry: false,
      passwordExpiryDays: 90,
      preventPasswordReuse: true,
      passwordHistoryCount: 5,
      loginAlerts: true,
      newDeviceAlerts: true,
      failedLoginAlerts: true,
      maxFailedAttempts: 5,
      lockAfterFailedAttempts: true,
      lockDurationMinutes: 30,
      singleSessionOnly: false,
      sessionTimeout: true,
      autoLogoutOnInactivity: true,
      inactivityTimeoutMinutes: 15,
      deviceManagement: true,
      allowMultipleDevices: true,
      maxDevicesAllowed: 3,
      ipWhitelist: false,
      allowedIps: [],
      locationRestriction: false,
      allowedCountries: [],
      encryptData: true,
      backupData: true,
      autoBackup: true,
      backupFrequencyDays: 7,
      lastUpdated: DateTime.now(),
      updatedBy: GlobalIdService.firestoreId,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      // Authentication Security
      'twoFactorAuth': twoFactorAuth,
      'biometricLogin': biometricLogin,
      'rememberMe': rememberMe,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,

      // Password Security
      'requireStrongPassword': requireStrongPassword,
      'passwordExpiry': passwordExpiry,
      'passwordExpiryDays': passwordExpiryDays,
      'preventPasswordReuse': preventPasswordReuse,
      'passwordHistoryCount': passwordHistoryCount,

      // Login Security
      'loginAlerts': loginAlerts,
      'newDeviceAlerts': newDeviceAlerts,
      'failedLoginAlerts': failedLoginAlerts,
      'maxFailedAttempts': maxFailedAttempts,
      'lockAfterFailedAttempts': lockAfterFailedAttempts,
      'lockDurationMinutes': lockDurationMinutes,

      // Session Management
      'singleSessionOnly': singleSessionOnly,
      'sessionTimeout': sessionTimeout,
      'autoLogoutOnInactivity': autoLogoutOnInactivity,
      'inactivityTimeoutMinutes': inactivityTimeoutMinutes,

      // Device Management
      'deviceManagement': deviceManagement,
      'allowMultipleDevices': allowMultipleDevices,
      'maxDevicesAllowed': maxDevicesAllowed,

      // IP & Location Security
      'ipWhitelist': ipWhitelist,
      'allowedIps': allowedIps,
      'locationRestriction': locationRestriction,
      'allowedCountries': allowedCountries,

      // Data Security
      'encryptData': encryptData,
      'backupData': backupData,
      'autoBackup': autoBackup,
      'backupFrequencyDays': backupFrequencyDays,

      // Metadata
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': GlobalIdService.firestoreId,
    };
  }

  // Create from Firestore document
  factory SecuritySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SecuritySettings(
      twoFactorAuth: data['twoFactorAuth'] ?? false,
      biometricLogin: data['biometricLogin'] ?? false,
      rememberMe: data['rememberMe'] ?? true,
      sessionTimeoutMinutes: data['sessionTimeoutMinutes'] ?? 30,
      requireStrongPassword: data['requireStrongPassword'] ?? true,
      passwordExpiry: data['passwordExpiry'] ?? false,
      passwordExpiryDays: data['passwordExpiryDays'] ?? 90,
      preventPasswordReuse: data['preventPasswordReuse'] ?? true,
      passwordHistoryCount: data['passwordHistoryCount'] ?? 5,
      loginAlerts: data['loginAlerts'] ?? true,
      newDeviceAlerts: data['newDeviceAlerts'] ?? true,
      failedLoginAlerts: data['failedLoginAlerts'] ?? true,
      maxFailedAttempts: data['maxFailedAttempts'] ?? 5,
      lockAfterFailedAttempts: data['lockAfterFailedAttempts'] ?? true,
      lockDurationMinutes: data['lockDurationMinutes'] ?? 30,
      singleSessionOnly: data['singleSessionOnly'] ?? false,
      sessionTimeout: data['sessionTimeout'] ?? true,
      autoLogoutOnInactivity: data['autoLogoutOnInactivity'] ?? true,
      inactivityTimeoutMinutes: data['inactivityTimeoutMinutes'] ?? 15,
      deviceManagement: data['deviceManagement'] ?? true,
      allowMultipleDevices: data['allowMultipleDevices'] ?? true,
      maxDevicesAllowed: data['maxDevicesAllowed'] ?? 3,
      ipWhitelist: data['ipWhitelist'] ?? false,
      allowedIps: List<String>.from(data['allowedIps'] ?? []),
      locationRestriction: data['locationRestriction'] ?? false,
      allowedCountries: List<String>.from(data['allowedCountries'] ?? []),
      encryptData: data['encryptData'] ?? true,
      backupData: data['backupData'] ?? true,
      autoBackup: data['autoBackup'] ?? true,
      backupFrequencyDays: data['backupFrequencyDays'] ?? 7,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
    );
  }

  // Create a copy with updated values
  SecuritySettings copyWith({
    bool? twoFactorAuth,
    bool? biometricLogin,
    bool? rememberMe,
    int? sessionTimeoutMinutes,
    bool? requireStrongPassword,
    bool? passwordExpiry,
    int? passwordExpiryDays,
    bool? preventPasswordReuse,
    int? passwordHistoryCount,
    bool? loginAlerts,
    bool? newDeviceAlerts,
    bool? failedLoginAlerts,
    int? maxFailedAttempts,
    bool? lockAfterFailedAttempts,
    int? lockDurationMinutes,
    bool? singleSessionOnly,
    bool? sessionTimeout,
    bool? autoLogoutOnInactivity,
    int? inactivityTimeoutMinutes,
    bool? deviceManagement,
    bool? allowMultipleDevices,
    int? maxDevicesAllowed,
    bool? ipWhitelist,
    List<String>? allowedIps,
    bool? locationRestriction,
    List<String>? allowedCountries,
    bool? encryptData,
    bool? backupData,
    bool? autoBackup,
    int? backupFrequencyDays,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return SecuritySettings(
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      biometricLogin: biometricLogin ?? this.biometricLogin,
      rememberMe: rememberMe ?? this.rememberMe,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      requireStrongPassword: requireStrongPassword ?? this.requireStrongPassword,
      passwordExpiry: passwordExpiry ?? this.passwordExpiry,
      passwordExpiryDays: passwordExpiryDays ?? this.passwordExpiryDays,
      preventPasswordReuse: preventPasswordReuse ?? this.preventPasswordReuse,
      passwordHistoryCount: passwordHistoryCount ?? this.passwordHistoryCount,
      loginAlerts: loginAlerts ?? this.loginAlerts,
      newDeviceAlerts: newDeviceAlerts ?? this.newDeviceAlerts,
      failedLoginAlerts: failedLoginAlerts ?? this.failedLoginAlerts,
      maxFailedAttempts: maxFailedAttempts ?? this.maxFailedAttempts,
      lockAfterFailedAttempts: lockAfterFailedAttempts ?? this.lockAfterFailedAttempts,
      lockDurationMinutes: lockDurationMinutes ?? this.lockDurationMinutes,
      singleSessionOnly: singleSessionOnly ?? this.singleSessionOnly,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      autoLogoutOnInactivity: autoLogoutOnInactivity ?? this.autoLogoutOnInactivity,
      inactivityTimeoutMinutes: inactivityTimeoutMinutes ?? this.inactivityTimeoutMinutes,
      deviceManagement: deviceManagement ?? this.deviceManagement,
      allowMultipleDevices: allowMultipleDevices ?? this.allowMultipleDevices,
      maxDevicesAllowed: maxDevicesAllowed ?? this.maxDevicesAllowed,
      ipWhitelist: ipWhitelist ?? this.ipWhitelist,
      allowedIps: allowedIps ?? this.allowedIps,
      locationRestriction: locationRestriction ?? this.locationRestriction,
      allowedCountries: allowedCountries ?? this.allowedCountries,
      encryptData: encryptData ?? this.encryptData,
      backupData: backupData ?? this.backupData,
      autoBackup: autoBackup ?? this.autoBackup,
      backupFrequencyDays: backupFrequencyDays ?? this.backupFrequencyDays,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if password meets security requirements
  bool isPasswordStrong(String password) {
    if (!requireStrongPassword) return true;

    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final hasMinLength = password.length >= 8;

    return hasUpperCase && hasLowerCase && hasDigits && hasSpecialChars && hasMinLength;
  }

  // Check if session has expired
  bool isSessionExpired(DateTime lastActivity) {
    if (!sessionTimeout && !autoLogoutOnInactivity) return false;

    final timeoutMinutes = sessionTimeout
        ? sessionTimeoutMinutes
        : inactivityTimeoutMinutes;

    final elapsedMinutes = DateTime.now().difference(lastActivity).inMinutes;
    return elapsedMinutes >= timeoutMinutes;
  }

  // Check if device is allowed
  bool isDeviceAllowed(String deviceId, List<String> allowedDevices) {
    if (!deviceManagement) return true;
    if (allowMultipleDevices) {
      return allowedDevices.contains(deviceId) || allowedDevices.length < maxDevicesAllowed;
    }
    return allowedDevices.contains(deviceId);
  }

  // Check if IP is allowed
  bool isIpAllowed(String ip) {
    if (!ipWhitelist) return true;
    return allowedIps.contains(ip);
  }

  // Check if location is allowed
  bool isLocationAllowed(String countryCode) {
    if (!locationRestriction) return true;
    return allowedCountries.contains(countryCode.toUpperCase());
  }
}