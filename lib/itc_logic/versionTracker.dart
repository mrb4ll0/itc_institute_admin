import 'package:flutter/material.dart';

class VersionTracker {
  // Singleton instance
  static final VersionTracker _instance = VersionTracker._internal();

  // Private constructor
  VersionTracker._internal();

  // Factory constructor to return the singleton instance
  factory VersionTracker() => _instance;

  // Version information
   String appName = 'IT Connect';
   String version = '2.1.0';
   int buildNumber = 15;
   String releaseDate = 'December 2025';
   String platform = 'Android';
   String edition = 'Company';

  // Company information
  final String companyName = 'IT Connect Inc.';
  final String copyright = '© 2025 IT Connect Inc. All rights reserved.';
  final String website = 'https://itconnect.com';
  final String supportEmail = 'support@itconnect.com';
  final String privacyPolicyUrl = 'https://itconnect.com/privacy';
  final String termsOfServiceUrl = 'https://itconnect.com/terms';

  // Contact information
  final String phone = '+234 800 000 0000';
  final String address = 'Tech Hub, Lagos, Nigeria';
  final String officeHours = 'Mon-Fri, 9am-5pm WAT';

  // App features metadata
  final List<AppFeature> features = [
    AppFeature(
      name: 'Student Matching',
      description: 'AI-powered matching of students with companies',
      iconCodePoint: Icons.people.codePoint,
      color: Colors.blue.value,
    ),
    AppFeature(
      name: 'Company Portal',
      description: 'Comprehensive dashboard for company management',
      iconCodePoint: Icons.business.codePoint,
      color: Colors.green.value,
    ),
    AppFeature(
      name: 'Progress Tracking',
      description: 'Real-time monitoring of student performance',
      iconCodePoint: Icons.track_changes.codePoint,
      color: Colors.orange.value,
    ),
    AppFeature(
      name: 'Verified Profiles',
      description: 'Academic verification and background checks',
      iconCodePoint: Icons.verified.codePoint,
      color: Colors.purple.value,
    ),
  ];

  // Statistics (can be updated dynamically)
  Map<String, dynamic> statistics = {
    'students': '10,000+',
    'companies': '500+',
    'placements': '3,000+',
    'institutions': '50+',
  };

  // Methods to get formatted strings
  String getFullVersion() => '$version (Build $buildNumber)';

  String getVersionWithPlatform() => '$appName $version - $platform';

  String getAppInfo() => '$appName $edition Edition v$version';

  String getBuildInfo() => 'Build $buildNumber • $releaseDate';

  Map<String, String> getContactInfo() {
    return {
      'Email': supportEmail,
      'Phone': phone,
      'Website': website,
      'Address': address,
      'Hours': officeHours,
    };
  }

  // Update statistics
  void updateStatistics(Map<String, dynamic> newStats) {
    statistics.addAll(newStats);
  }

  // Check if update is available
  Future<bool> checkForUpdate() async {
    // You can implement actual update check logic here
    // For example, fetch from your backend API
    return false;
  }

  // Get minimum required version (for forced updates)
  Future<String> getMinimumRequiredVersion() async {
    // Fetch from backend or Firebase Remote Config
    return version;
  }

  // Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'version': version,
      'buildNumber': buildNumber,
      'releaseDate': releaseDate,
      'platform': platform,
      'edition': edition,
      'companyName': companyName,
      'copyright': copyright,
    };
  }

  // Factory method from JSON
  factory VersionTracker.fromJson(Map<String, dynamic> json) {
    // Since it's a singleton, we just update the values
    _instance.version = json['version'] ?? _instance.version;
    _instance.buildNumber = json['buildNumber'] ?? _instance.buildNumber;
    _instance.releaseDate = json['releaseDate'] ?? _instance.releaseDate;
    return _instance;
  }
}

// App Feature model for structured feature data
class AppFeature {
  final String name;
  final String description;
  final int iconCodePoint;
  final int color;

  AppFeature({
    required this.name,
    required this.description,
    required this.iconCodePoint,
    required this.color,
  });

  Icon get icon => Icon(IconData(iconCodePoint, fontFamily: 'MaterialIcons'));
  Color get colorValue => Color(color);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'color': color,
    };
  }
}