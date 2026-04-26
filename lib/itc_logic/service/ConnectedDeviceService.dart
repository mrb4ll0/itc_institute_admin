// itc_logic/service/connected_device_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../model/ConnectedDevice.dart';
import '../idservice/globalIdService.dart';


class ConnectedDeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _devicesCollection => _firestore
      .collection('users')
      .doc(
      GlobalIdService.firestoreId)
      .collection('connected_devices');

  // Save current device info on login
  Future<void> saveCurrentDevice() async {
    final userId = GlobalIdService.firestoreId;
    if (userId == null) return;

    try {
      final deviceInfo = await getCurrentDeviceInfo();
      final deviceId = await _getDeviceId();

      // Check if device already exists
      final existingDevice = await _devicesCollection.doc(deviceId).get();

      if (existingDevice.exists) {
        // Update last active timestamp
        await _devicesCollection.doc(deviceId).update({
          'lastActive': FieldValue.serverTimestamp(),
          'isCurrentDevice': true,
        });
      } else {
        // Add new device
        final newDevice = ConnectedDevice(
          id: deviceId,
          deviceName: deviceInfo['deviceName']!,
          deviceType: deviceInfo['deviceType']!,
          osVersion: deviceInfo['osVersion']!,
          browserName: deviceInfo['browserName'],
          ipAddress: deviceInfo['ipAddress']!,
          location: deviceInfo['location']!,
          lastActive: DateTime.now(),
          firstSeen: DateTime.now(),
          isCurrentDevice: true,
          fcmToken: deviceInfo['fcmToken'],
          deviceModel: deviceInfo['deviceModel'],
          manufacturer: deviceInfo['manufacturer'],
        );

        await _devicesCollection.doc(deviceId).set(newDevice.toFirestore());
      }

      // Set all other devices as not current
      await _setOtherDevicesAsNotCurrent(deviceId);

    } catch (e) {
      print('Error saving current device: $e');
    }
  }

  // Get all connected devices
  Stream<List<ConnectedDevice>> getConnectedDevices() {
    return _devicesCollection
        .orderBy('lastActive', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ConnectedDevice.fromFirestore(doc, doc.id);
      }).toList();
    });
  }

  // Get all connected devices (Future version)
  Future<List<ConnectedDevice>> getConnectedDevicesFuture() async {
    final snapshot = await _devicesCollection
        .orderBy('lastActive', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return ConnectedDevice.fromFirestore(doc, doc.id);
    }).toList();
  }

  // Revoke a specific device
  Future<void> revokeDevice(String deviceId) async {
    final userId = GlobalIdService.firestoreId;
    if (userId == null) throw Exception('User not logged in');

    await _devicesCollection.doc(deviceId).delete();

    // Optional: Send notification to that device to log out
    await _sendRevokeNotification(deviceId);
  }

  // Revoke all devices except current
  Future<void> revokeAllOtherDevices(String currentDeviceId) async {
    final userId = GlobalIdService.firestoreId;
    if (userId == null) throw Exception('User not logged in');

    final devices = await _devicesCollection.get();

    for (var doc in devices.docs) {
      if (doc.id != currentDeviceId) {
        await doc.reference.delete();
        await _sendRevokeNotification(doc.id);
      }
    }
  }

  // Update current device last active timestamp
  Future<void> updateLastActive() async {
    final deviceId = await _getDeviceId();
    await _devicesCollection.doc(deviceId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // Mark a device as current
  Future<void> setCurrentDevice(String deviceId) async {
    await _setOtherDevicesAsNotCurrent(deviceId);
    await _devicesCollection.doc(deviceId).update({
      'isCurrentDevice': true,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // Helper: Set all other devices as not current
  Future<void> _setOtherDevicesAsNotCurrent(String currentDeviceId) async {
    final devices = await _devicesCollection.get();

    for (var doc in devices.docs) {
      if (doc.id != currentDeviceId) {
        await doc.reference.update({'isCurrentDevice': false});
      }
    }
  }

  // Helper: Get unique device ID
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown';
    } else {
      return 'web_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Get current device info
  Future<Map<String, dynamic>> getCurrentDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final info = NetworkInfo();

    String deviceName = 'Unknown Device';
    String deviceType = 'Unknown';
    String osVersion = 'Unknown';
    String? deviceModel;
    String? manufacturer;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = androidInfo.model;
      deviceType = 'Android Phone';
      osVersion = 'Android ${androidInfo.version.release}';
      deviceModel = androidInfo.model;
      manufacturer = androidInfo.manufacturer;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.model;
      deviceType = 'iOS Device';
      osVersion = 'iOS ${iosInfo.systemVersion}';
      deviceModel = iosInfo.model;
      manufacturer = 'Apple';
    } else if (Platform.isWindows) {
      deviceType = 'Windows PC';
      deviceName = 'Windows Computer';
    } else if (Platform.isMacOS) {
      deviceType = 'Mac Computer';
      deviceName = 'Mac Computer';
    } else {
      deviceType = 'Web Browser';
      deviceName = 'Web Browser';
    }

    final ipAddress = await _getIpAddress();
    final location = await _getLocation();

    return {
      'deviceName': deviceName,
      'deviceType': deviceType,
      'osVersion': osVersion,
      'browserName': null,
      'ipAddress': ipAddress,
      'location': location,
      'deviceModel': deviceModel,
      'manufacturer': manufacturer,
      'fcmToken': null,
    };
  }

  // Get IP address
  Future<String> _getIpAddress() async {
    try {
      final info = NetworkInfo();
      final localIp = await info.getWifiIP();
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }
      return localIp ?? 'Unknown IP';
    } catch (e) {
      return 'Unknown IP';
    }
  }

  // Get location
  Future<String> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );

        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          String location = '';
          if (place.locality != null) location += place.locality!;
          if (place.country != null) {
            if (location.isNotEmpty) location += ', ';
            location += place.country!;
          }
          return location.isEmpty ? 'Unknown Location' : location;
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
    return 'Unknown Location';
  }

  // Send notification to revoke device
  Future<void> _sendRevokeNotification(String deviceId) async {
    // Implement notification logic if needed
    // This could send an FCM message to the device to log out
  }

  // Remove all devices (when user deletes account)
  Future<void> deleteAllDevices() async {
    final userId = GlobalIdService.firestoreId;
    if (userId == null) return;

    final devices = await _devicesCollection.get();
    for (var doc in devices.docs) {
      await doc.reference.delete();
    }
  }
}