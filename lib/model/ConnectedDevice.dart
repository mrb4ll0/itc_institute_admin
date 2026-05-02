// models/device_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum DeviceStatus {
  active,      // Currently using the account
  blocked,     // Blocked from accessing account
  removed,     // Removed by admin
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
  web,
  unknown,
}

class ConnectedDevice {
  final String deviceId;
  final String userId;
  final String deviceName;
  final String deviceType;
  final String ipAddress;
  final String location;
  final String? fcmToken;
  final DateTime firstLoginAt;
  final DateTime lastActiveAt;
  final DeviceStatus status;
   bool isAdminDevice;
  final String? osVersion;
  final String? appVersion;

  ConnectedDevice({
    required this.deviceId,
    required this.userId,
    required this.deviceName,
    required this.deviceType,
    required this.ipAddress,
    required this.location,
    this.fcmToken,
    required this.firstLoginAt,
    required this.lastActiveAt,
    required this.status,
    required this.isAdminDevice,
    this.osVersion,
    this.appVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'ipAddress': ipAddress,
      'location': location,
      'fcmToken': fcmToken,
      'firstLoginAt': firstLoginAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'status': status.name,
      'isAdminDevice': isAdminDevice,
      'osVersion': osVersion,
      'appVersion': appVersion,
    };
  }

  factory ConnectedDevice.fromMap(Map<String, dynamic> map) {
    return ConnectedDevice(
      deviceId: map['deviceId'],
      userId: map['userId'],
      deviceName: map['deviceName'],
      deviceType: map['deviceType'],
      ipAddress: map['ipAddress'],
      location: map['location'],
      fcmToken: map['fcmToken'],
      firstLoginAt: DateTime.parse(map['firstLoginAt']),
      lastActiveAt: DateTime.parse(map['lastActiveAt']),
      status: DeviceStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => DeviceStatus.active,
      ),
      isAdminDevice: map['isAdminDevice'] ?? false,
      osVersion: map['osVersion'],
      appVersion: map['appVersion'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'ipAddress': ipAddress,
      'location': location,
      'fcmToken': fcmToken,
      'firstLoginAt': firstLoginAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'status': status.name,
      'isAdminDevice': isAdminDevice,
      'osVersion': osVersion,
      'appVersion': appVersion,
    };
  }

  // device_model.dart
  factory ConnectedDevice.fromFirestore(Map<String, dynamic> data) {
    return ConnectedDevice(
      deviceId: data['deviceId'],
      userId: data['userId'],
      deviceName: data['deviceName'],
      deviceType: data['deviceType'],
      ipAddress: data['ipAddress'],
      location: data['location'],
      fcmToken: data['fcmToken'],
      firstLoginAt: DateTime.parse(data['firstLoginAt']),  // ✅ Parse ISO string
      lastActiveAt: DateTime.parse(data['lastActiveAt']),  // ✅ Parse ISO string
      status: DeviceStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => DeviceStatus.active,
      ),
      isAdminDevice: data['isAdminDevice'] ?? false,
      osVersion: data['osVersion'],
      appVersion: data['appVersion'],
    );
  }

  ConnectedDevice copyWith({
    String? deviceId,
    String? userId,
    String? deviceName,
    String? deviceType,
    String? ipAddress,
    String? location,
    String? fcmToken,
    DateTime? lastActiveAt,
    DeviceStatus? status,
    bool? isAdminDevice,
  }) {
    return ConnectedDevice(
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      firstLoginAt: firstLoginAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      status: status ?? this.status,
      isAdminDevice: isAdminDevice ?? this.isAdminDevice,
      osVersion: osVersion,
      appVersion: appVersion,
    );
  }

  String getStatusIcon() {
    switch (status) {
      case DeviceStatus.active:
        return '✅';
      case DeviceStatus.blocked:
        return '🚫';
      case DeviceStatus.removed:
        return '🗑️';
    }
  }

  Color getStatusColor() {
    switch (status) {
      case DeviceStatus.active:
        return Colors.green;
      case DeviceStatus.blocked:
        return Colors.red;
      case DeviceStatus.removed:
        return Colors.grey;
    }
  }
}