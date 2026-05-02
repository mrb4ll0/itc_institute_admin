// services/device_service.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../model/ConnectedDevice.dart';
import '../../model/notificationModel.dart';
import '../../model/notificationSettingModel.dart';
import '../localDB/sharedPreference.dart';
import '../notification/notificationPanel/notificationPanelService.dart';

class ConnectedDeviceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'user_devices';

  // 🔥 CACHE: Store current device in memory
  static ConnectedDevice? _cachedDevice;
  static DateTime? _cachedDeviceTime;
  static String? _cachedEmail;

  // Generate unique device ID
  static Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return 'android_${androidInfo.id}_${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return 'ios_${iosInfo.identifierForVendor}_${DateTime.now().millisecondsSinceEpoch}';
    }
    return 'web_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Generate device fingerprint for identification
  static Future<String> _generateDeviceFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.id}_${androidInfo.model}_${androidInfo.manufacturer}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.identifierForVendor}_${iosInfo.model}';
    }
    return Platform.localHostname;
  }

  // 🔥 NEW: Get or create device (with caching)
  static Future<ConnectedDevice> getOrCreateDevice({
    required String userId,
    required String email,
    bool forceRefresh = false,
  }) async {
    try {
      // 1. Check memory cache first (super fast)
      if (!forceRefresh &&
          _cachedDevice != null &&
          _cachedDeviceTime != null &&
          _cachedEmail == email) {
        final cacheAge = DateTime.now().difference(_cachedDeviceTime!);
        if (cacheAge.inMinutes < 5) { // Cache valid for 5 minutes
          debugPrint('📦 Returning cached device: ${_cachedDevice!.deviceName}');

          // Update last active in background
          unawaited(_updateLastActiveInBackground(
            userId,
            _cachedDevice!.deviceId,
            email,
          ));

          return _cachedDevice!;
        }
      }

      // 2. Check local SharedPreferences for existing device
      final cachedDevices = await UserPreferences.getUserDevices(email);
      final deviceName = await _getDeviceNameFast();
      final existingLocalDevice = cachedDevices.firstWhereOrNull(
            (d) => d.deviceName == deviceName,
      );

      if (existingLocalDevice != null) {
        debugPrint('✅ Found existing device in local cache: ${existingLocalDevice.deviceName}');

        // Update last active
        final updatedDevice = existingLocalDevice.copyWith(
          lastActiveAt: DateTime.now(),
          fcmToken: await FirebaseMessaging.instance.getToken(),
        );

        // Update in background
        unawaited(_updateDeviceLastActive(userId, existingLocalDevice.deviceId));
        unawaited(UserPreferences.addOrUpdateDevice(email, updatedDevice));

        // Cache it
        _cachedDevice = updatedDevice;
        _cachedDeviceTime = DateTime.now();
        _cachedEmail = email;

        return updatedDevice;
      }

      // 3. Check Firestore for existing device
      final firestoreDevices = await getUserDevicesFromFirestore(userId);
      final existingFirestoreDevice = firestoreDevices.firstWhereOrNull(
            (d) => d.deviceName == deviceName,
      );

      if (existingFirestoreDevice != null) {
        debugPrint('✅ Found existing device in Firestore: ${existingFirestoreDevice.deviceName}');

        // Sync to local cache
        await UserPreferences.addOrUpdateDevice(email, existingFirestoreDevice);

        // Update last active
        final updatedDevice = existingFirestoreDevice.copyWith(
          lastActiveAt: DateTime.now(),
          fcmToken: await FirebaseMessaging.instance.getToken(),
        );

        unawaited(_updateDeviceLastActive(userId, existingFirestoreDevice.deviceId));
        unawaited(UserPreferences.addOrUpdateDevice(email, updatedDevice));

        // Cache it
        _cachedDevice = updatedDevice;
        _cachedDeviceTime = DateTime.now();
        _cachedEmail = email;

        return updatedDevice;
      }

      // 4. No device found - create new one (only happens once per device)
      debugPrint('🆕 No existing device found, creating new one for: $deviceName');
      final newDevice = await _createNewDevice(userId, email);

      // Cache it
      _cachedDevice = newDevice;
      _cachedDeviceTime = DateTime.now();
      _cachedEmail = email;

      return newDevice;

    } catch (e, stackTrace) {
      debugPrint('❌ Error in getOrCreateDevice: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // 🔥 NEW: Create new device (only called when device doesn't exist)
  static Future<ConnectedDevice> _createNewDevice(String userId, String email) async {
    final deviceId = await _generateDeviceId();
    final deviceName = await _getDeviceNameFast();
    final deviceType = await _getDeviceType();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final osVersion = await _getOSVersionFast();
    final appVersion = await _getAppVersion();

    // Create device with placeholder values for heavy fields
    final newDevice = ConnectedDevice(
      deviceId: deviceId,
      userId: userId,
      deviceName: deviceName,
      deviceType: deviceType,
      ipAddress: "Updating...",
      location: "Updating...",
      fcmToken: fcmToken,
      firstLoginAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      status: DeviceStatus.active,
      isAdminDevice: false,
      osVersion: osVersion,
      appVersion: appVersion,
    );

    // Check if this is the first device
    final existingDevices = await getUserDevicesFromFirestore(userId);

    if (existingDevices.isEmpty) {
      newDevice.isAdminDevice = true;
      debugPrint('👑 First device, set as admin device');
    } else {
      // Notify admin about new device in background
      unawaited(_notifyAdminDevice(userId, deviceName, "Updating...", "Updating..."));
    }

    // Save to Firestore
    await _saveDeviceToFirestore(userId, newDevice);

    // Save to local SharedPreferences
    await UserPreferences.addOrUpdateDevice(email, newDevice);
    await UserPreferences.saveCurrentDeviceId(deviceId);

    // Update with full details in background (IP, location)
    unawaited(_updateDeviceWithFullDetails(userId, deviceId, email));

    debugPrint('✅ New device created and saved: $deviceName');
    return newDevice;
  }

  // 🔥 NEW: Update device with full details in background
  static Future<void> _updateDeviceWithFullDetails(
      String userId,
      String deviceId,
      String email,
      ) async {
    try {
      final ipAddress = await _getIpAddress();
      final location = await _getLocation();

      // Update Firestore
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> devices = data['devices'] ?? [];

        final updatedDevices = devices.map((device) {
          final deviceMap = device as Map<String, dynamic>;
          if (deviceMap['deviceId'] == deviceId) {
            deviceMap['ipAddress'] = ipAddress;
            deviceMap['location'] = location;
          }
          return deviceMap;
        }).toList();

        await docRef.update({'devices': updatedDevices});

        // Update local cache
        final devicesList = await UserPreferences.getUserDevices(email);
        final index = devicesList.indexWhere((d) => d.deviceId == deviceId);
        if (index != -1) {
          final updatedDevice = devicesList[index].copyWith(
            ipAddress: ipAddress,
            location: location,
          );
          await UserPreferences.addOrUpdateDevice(email, updatedDevice);

          // Update memory cache
          if (_cachedDevice?.deviceId == deviceId) {
            _cachedDevice = updatedDevice;
          }
        }
      }

      debugPrint('✅ Device details updated: IP=$ipAddress, Location=$location');
    } catch (e) {
      debugPrint('Error updating device details: $e');
    }
  }

  // 🔥 NEW: Update last active in background
  static Future<void> _updateLastActiveInBackground(
      String userId,
      String deviceId,
      String email,
      ) async {
    try {
      await _updateDeviceLastActive(userId, deviceId);

      // Update local cache
      final devices = await UserPreferences.getUserDevices(email);
      final index = devices.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        final updatedDevice = devices[index].copyWith(
          lastActiveAt: DateTime.now(),
        );
        await UserPreferences.addOrUpdateDevice(email, updatedDevice);

        // Update memory cache
        if (_cachedDevice?.deviceId == deviceId) {
          _cachedDevice = updatedDevice;
          _cachedDeviceTime = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint('Error updating last active: $e');
    }
  }

  // 🔥 Keep original saveCurrentDevice for backward compatibility
  static Future<ConnectedDevice> saveCurrentDevice({
    required String userId,
    required String email,
  }) async {
    // Use the new cached method
    return await getOrCreateDevice(userId: userId, email: email);
  }

  // Save device to Firestore
  static Future<void> _saveDeviceToFirestore(String userId, ConnectedDevice device) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> existingDevices = data['devices'] ?? [];

        final existingIndex = existingDevices.indexWhere(
                (d) => (d as Map)['deviceId'] == device.deviceId
        );

        if (existingIndex != -1) {
          final updatedDevice = device.toFirestore();
          existingDevices[existingIndex] = updatedDevice;
        } else {
          existingDevices.add(device.toFirestore());
        }

        await docRef.update({'devices': existingDevices});
      } else {
        await docRef.set({
          'devices': [device.toFirestore()],
          'userId': userId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      debugPrint('✅ Device saved to Firestore: ${device.deviceName}');
    } catch (e) {
      debugPrint('❌ Error saving device to Firestore: $e');
      rethrow;
    }
  }

  // Get all user devices from Firestore
  static Future<List<ConnectedDevice>> getUserDevicesFromFirestore(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final devicesList = data['devices'] as List<dynamic>?;

        if (devicesList != null) {
          final devices = <ConnectedDevice>[];
          for (var deviceMap in devicesList) {
            try {
              final device = ConnectedDevice.fromFirestore(deviceMap as Map<String, dynamic>);
              devices.add(device);
            } catch (e) {
              debugPrint('Error parsing device: $e');
            }
          }
          return devices;
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting devices from Firestore: $e');
      return [];
    }
  }

  // Update device last active time
  static Future<void> _updateDeviceLastActive(String userId, String deviceId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> devices = data['devices'] ?? [];

        final updatedDevices = devices.map((device) {
          if (device['deviceId'] == deviceId) {
            device['lastActiveAt'] = DateTime.now().toIso8601String();
          }
          return device;
        }).toList();

        await docRef.update({'devices': updatedDevices});
      }
    } catch (e) {
      debugPrint('❌ Error updating device last active: $e');
    }
  }

  // Block a device
  static Future<void> blockDevice(String userId, String deviceId, String email) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> devices = data['devices'] ?? [];

        final updatedDevices = devices.map((device) {
          if (device['deviceId'] == deviceId) {
            device['status'] = 'blocked';
          }
          return device;
        }).toList();

        await docRef.update({'devices': updatedDevices});

        // Update local cache
        await UserPreferences.updateDeviceStatus(email, deviceId, DeviceStatus.blocked);

        // Clear memory cache if this device is blocked
        if (_cachedDevice?.deviceId == deviceId) {
          _cachedDevice = null;
          _cachedDeviceTime = null;
        }

        debugPrint('✅ Device blocked: $deviceId');
      }
    } catch (e) {
      debugPrint('❌ Error blocking device: $e');
      rethrow;
    }
  }

  // Remove a device
  static Future<void> removeDevice(String userId, String deviceId, String email) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> devices = data['devices'] ?? [];

        devices.removeWhere((device) => device['deviceId'] == deviceId);

        await docRef.update({'devices': devices});

        // Update local cache
        await UserPreferences.removeDevice(email, deviceId);

        // Clear memory cache if this device is removed
        if (_cachedDevice?.deviceId == deviceId) {
          _cachedDevice = null;
          _cachedDeviceTime = null;
        }

        debugPrint('✅ Device removed: $deviceId');
      }
    } catch (e) {
      debugPrint('❌ Error removing device: $e');
      rethrow;
    }
  }

  // Set admin device
  static Future<void> setAdminDevice(String userId, String deviceId, String email) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> devices = data['devices'] ?? [];

        final updatedDevices = devices.map((device) {
          device['isAdminDevice'] = (device['deviceId'] == deviceId);
          return device;
        }).toList();

        await docRef.update({'devices': updatedDevices});

        // Update local cache
        await UserPreferences.setAdminDevice(email, deviceId);

        // Update memory cache
        if (_cachedDevice?.deviceId == deviceId) {
          _cachedDevice = _cachedDevice?.copyWith(isAdminDevice: true);
        }

        debugPrint('✅ Admin device set: $deviceId');
      }
    } catch (e) {
      debugPrint('❌ Error setting admin device: $e');
      rethrow;
    }
  }

  // Check if current device is allowed to access
  static Future<bool> isDeviceAllowed(String userId, String deviceId, String email) async {
    try {
      // First check memory cache
      if (_cachedDevice != null && _cachedDevice!.deviceId == deviceId) {
        return _cachedDevice!.status == DeviceStatus.active;
      }

      // Then check local cache
      final devices = await UserPreferences.getUserDevices(email);
      final localDevice = devices.where((d) => d.deviceId == deviceId).firstOrNull;

      if (localDevice != null) {
        return localDevice.status == DeviceStatus.active;
      }

      // Finally check Firestore
      final devicesFromCloud = await getUserDevicesFromFirestore(userId);
      final device = devicesFromCloud.where((d) => d.deviceId == deviceId).firstOrNull;

      return device != null && device.status == DeviceStatus.active;
    } catch (e) {
      debugPrint('❌ Error checking device access: $e');
      return true; // Allow access on error
    }
  }

  // 🔥 NEW: Clear cache (useful for logout)
  static void clearCache() {
    _cachedDevice = null;
    _cachedDeviceTime = null;
    _cachedEmail = null;
    debugPrint('🗑️ Device cache cleared');
  }

  // Fast device name (no heavy operations)
  static Future<String> _getDeviceNameFast() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.model;
    }
    return "Web Browser";
  }

  // Helper methods
  static Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "${androidInfo.manufacturer} ${androidInfo.model}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.model;
    }
    return "Web Browser";
  }

  static Future<String> _getDeviceType() async {
    if (Platform.isAndroid) return 'mobile';
    if (Platform.isIOS) return 'mobile';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return 'desktop';
    return 'web';
  }

  static Future<String> _getOSVersionFast() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "Android ${androidInfo.version.release}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return "iOS ${iosInfo.systemVersion}";
    }
    return Platform.operatingSystem;
  }

  static Future<String> _getOSVersion() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "Android ${androidInfo.version.release}";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return "iOS ${iosInfo.systemVersion}";
    }
    return Platform.operatingSystem;
  }

  static Future<String> _getAppVersion() async {
    return "1.0.0";
  }

  static Future<String> _getIpAddress() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Error getting IP: $e');
    }
    return "Unknown IP";
  }

  static Future<String> _getLocation() async {
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
      debugPrint('Error getting location: $e');
    }
    return 'Unknown Location';
  }

  // Notify admin device about new login
  static Future<void> _notifyAdminDevice(
      String userId,
      String deviceName,
      String location,
      String ipAddress,
      ) async {
    try {
      final devices = await getUserDevicesFromFirestore(userId);
      final adminDevice = devices.where((d) => d.isAdminDevice).firstOrNull;

      if (adminDevice != null && adminDevice.fcmToken != null) {
        final notification = NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: "🔐 New Device Login",
          body: "Your account was accessed from a new device:\n"
              "📱 Device: $deviceName\n"
              "📍 Location: $location\n"
              "🌐 IP: $ipAddress\n"
              "🕐 Time: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}\n\n"
              "If this wasn't you, block this device immediately.",
          timestamp: DateTime.now(),
          read: false,
          targetAudience: adminDevice.fcmToken!,
          targetStudentId: userId,
          fcmToken: adminDevice.fcmToken!,
          type: NotificationType.securityAlerts.name,
        );

        await NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(
          notification,
        );
      }
    } catch (e) {
      debugPrint('Error notifying admin device: $e');
    }
  }
}

// Extension for firstOrNull
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}