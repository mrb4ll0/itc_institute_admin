import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectedDevice {
  final String id;
  final String deviceName;
  final String deviceType;
  final String osVersion;
  final String? browserName;
  final String ipAddress;
  final String location;
  final DateTime lastActive;
  final DateTime firstSeen;
  final bool isCurrentDevice;
  final String? fcmToken;
  final String? deviceModel;
  final String? manufacturer;

  ConnectedDevice({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.osVersion,
    this.browserName,
    required this.ipAddress,
    required this.location,
    required this.lastActive,
    required this.firstSeen,
    required this.isCurrentDevice,
    this.fcmToken,
    this.deviceModel,
    this.manufacturer,
  });

  factory ConnectedDevice.fromFirestore(DocumentSnapshot doc, String docId) {
    final data = doc.data() as Map<String, dynamic>;
    return ConnectedDevice(
      id: docId,
      deviceName: data['deviceName'] ?? 'Unknown Device',
      deviceType: data['deviceType'] ?? 'Unknown',
      osVersion: data['osVersion'] ?? 'Unknown',
      browserName: data['browserName'],
      ipAddress: data['ipAddress'] ?? 'Unknown',
      location: data['location'] ?? 'Unknown',
      lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstSeen: (data['firstSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCurrentDevice: data['isCurrentDevice'] ?? false,
      fcmToken: data['fcmToken'],
      deviceModel: data['deviceModel'],
      manufacturer: data['manufacturer'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceName': deviceName,
      'deviceType': deviceType,
      'osVersion': osVersion,
      'browserName': browserName,
      'ipAddress': ipAddress,
      'location': location,
      'lastActive': Timestamp.fromDate(lastActive),
      'firstSeen': Timestamp.fromDate(firstSeen),
      'isCurrentDevice': isCurrentDevice,
      'fcmToken': fcmToken,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
    };
  }

  ConnectedDevice copyWith({
    String? id,
    String? deviceName,
    String? deviceType,
    String? osVersion,
    String? browserName,
    String? ipAddress,
    String? location,
    DateTime? lastActive,
    DateTime? firstSeen,
    bool? isCurrentDevice,
    String? fcmToken,
    String? deviceModel,
    String? manufacturer,
  }) {
    return ConnectedDevice(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      osVersion: osVersion ?? this.osVersion,
      browserName: browserName ?? this.browserName,
      ipAddress: ipAddress ?? this.ipAddress,
      location: location ?? this.location,
      lastActive: lastActive ?? this.lastActive,
      firstSeen: firstSeen ?? this.firstSeen,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      fcmToken: fcmToken ?? this.fcmToken,
      deviceModel: deviceModel ?? this.deviceModel,
      manufacturer: manufacturer ?? this.manufacturer,
    );
  }
}