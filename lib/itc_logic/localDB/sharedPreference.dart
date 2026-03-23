import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/notificationSettingModel.dart';

class UserPreferences {
  static const String _userPrefix = "user_";
  static const String _notificationSettingsPrefix = "notification_settings_";

  /// Save user data after signup or login
  static Future<void> saveUser(Map<String, dynamic> userMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = userMap['email'];
      if (email == null) throw Exception('User map must contain an email field.');

      final key = _userPrefix + email;
      final jsonString = jsonEncode(userMap);
      await prefs.setString(key, jsonString);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Fetch user data on login using email
  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userPrefix + email;
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  /// Clear user data
  static Future<void> clearUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userPrefix + email;
    await prefs.remove(key);
  }

  // ==================== Notification Settings Methods ====================

  /// Save notification settings using the model
  static Future<void> saveNotificationSettings(
      String email,
      NotificationSettings settings,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notificationSettingsPrefix + email;
      final jsonString = jsonEncode(settings.toMap());
      await prefs.setString(key, jsonString);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Load notification settings using the model
  static Future<NotificationSettings> getNotificationSettings(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notificationSettingsPrefix + email;
      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        return NotificationSettings.defaultSettings();
      }

      final Map<String, dynamic> map = jsonDecode(jsonString);
      return NotificationSettings.fromMap(map);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      return NotificationSettings.defaultSettings();
    }
  }

  /// Update a single setting using the model
  static Future<void> updateNotificationSetting(
      String email,
      NotificationSettings Function(NotificationSettings) updateFunction,
      ) async {
    try {
      final settings = await getNotificationSettings(email);
      final updatedSettings = updateFunction(settings);
      await saveNotificationSettings(email, updatedSettings);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Clear notification settings
  static Future<void> clearNotificationSettings(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notificationSettingsPrefix + email;
      await prefs.remove(key);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Reset notification settings to default
  static Future<void> resetNotificationSettings(String email) async {
    try {
      final defaultSettings = NotificationSettings.defaultSettings();
      await saveNotificationSettings(email, defaultSettings);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Check if a specific notification type is enabled
  static Future<bool> isNotificationEnabled(
      String email,
      bool Function(NotificationSettings) checkFunction,
      ) async {
    try {
      final settings = await getNotificationSettings(email);
      return checkFunction(settings);
    } catch (e, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      return true;
    }
  }
}