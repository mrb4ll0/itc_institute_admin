import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/notificationSettingModel.dart';

class UserPreferences {
  static const String _userPrefix = "user_";
  static const String _notificationSettingsPrefix = "notification_settings_";
  static const String _accessTokenPrefix = "access_token_";
  static const String _refreshTokenPrefix = "refresh_token_";
  static const String _tokenExpiryPrefix = "token_expiry_";
  static const String _currentUserEmailKey = "current_user_email";

  /// Save user data after signup or login
  static Future<void> saveUser(Map<String, dynamic> userMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = userMap['email'];
      if (email == null) throw Exception('User map must contain an email field.');

      final key = _userPrefix + email;
      final jsonString = jsonEncode(userMap);
      await prefs.setString(key, jsonString);

      // Also save current user email
      await prefs.setString(_currentUserEmailKey, email);
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

  /// Get current user email
  static Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserEmailKey);
  }

  /// Clear user data
  static Future<void> clearUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userPrefix + email;
    await prefs.remove(key);

    // Also clear tokens for this user
    await clearTokens(email);

    // Clear current user email if it matches
    final currentEmail = await getCurrentUserEmail();
    if (currentEmail == email) {
      await prefs.remove(_currentUserEmailKey);
    }
  }

  // ==================== Token Management Methods ====================

  /// Save access token with optional expiry
  static Future<void> saveAccessToken({
    required String email,
    required String accessToken,
    int? expiresInSeconds, // Optional: token expiry time in seconds
    String? refreshToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenKey = _accessTokenPrefix + email;
      await prefs.setString(tokenKey, accessToken);

      // Save expiry time if provided
      if (expiresInSeconds != null) {
        final expiryTime = DateTime.now().add(Duration(seconds: expiresInSeconds));
        final expiryKey = _tokenExpiryPrefix + email;
        await prefs.setString(expiryKey, expiryTime.toIso8601String());
      }

      // Save refresh token if provided
      if (refreshToken != null) {
        final refreshKey = _refreshTokenPrefix + email;
        await prefs.setString(refreshKey, refreshToken);
      }

      debugPrint('✅ Access token saved for user: $email');
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving access token: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Get access token for a user
  static Future<String?> getAccessToken(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenKey = _accessTokenPrefix + email;
      final token = prefs.getString(tokenKey);

      if (token != null) {
        // Check if token is expired
        final isExpired = await isTokenExpired(email);
        if (isExpired) {
          debugPrint('⚠️ Access token is expired for user: $email');
          return null;
        }
      }

      return token;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting access token: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Get refresh token for a user
  static Future<String?> getRefreshToken(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshKey = _refreshTokenPrefix + email;
      return prefs.getString(refreshKey);
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting refresh token: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if token is expired
  static Future<bool> isTokenExpired(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryKey = _tokenExpiryPrefix + email;
      final expiryString = prefs.getString(expiryKey);

      if (expiryString == null) return false;

      final expiryTime = DateTime.parse(expiryString);
      final isExpired = DateTime.now().isAfter(expiryTime);

      if (isExpired) {
        debugPrint('🔑 Token expired at: $expiryTime');
      }

      return isExpired;
    } catch (e) {
      debugPrint('❌ Error checking token expiry: $e');
      return true; // Assume expired on error
    }
  }

  /// Get token expiry time
  static Future<DateTime?> getTokenExpiry(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryKey = _tokenExpiryPrefix + email;
      final expiryString = prefs.getString(expiryKey);

      if (expiryString == null) return null;
      return DateTime.parse(expiryString);
    } catch (e) {
      debugPrint('❌ Error getting token expiry: $e');
      return null;
    }
  }

  /// Get time remaining until token expires (in seconds)
  static Future<int?> getTokenRemainingSeconds(String email) async {
    final expiryTime = await getTokenExpiry(email);
    if (expiryTime == null) return null;

    final remainingSeconds = expiryTime.difference(DateTime.now()).inSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  /// Check if token needs refresh (e.g., less than 5 minutes remaining)
  static Future<bool> needsTokenRefresh(String email, {int bufferSeconds = 300}) async {
    final remainingSeconds = await getTokenRemainingSeconds(email);
    if (remainingSeconds == null) return true; // No token, needs refresh

    return remainingSeconds <= bufferSeconds;
  }

  /// Update access token (useful after refresh)
  static Future<void> updateAccessToken({
    required String email,
    required String newAccessToken,
    int? expiresInSeconds,
  }) async {
    await saveAccessToken(
      email: email,
      accessToken: newAccessToken,
      expiresInSeconds: expiresInSeconds,
    );
    debugPrint('🔄 Access token updated for user: $email');
  }

  /// Clear all tokens for a user
  static Future<void> clearTokens(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_accessTokenPrefix + email);
      await prefs.remove(_refreshTokenPrefix + email);
      await prefs.remove(_tokenExpiryPrefix + email);

      debugPrint('🗑️ All tokens cleared for user: $email');
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing tokens: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Clear all tokens for all users (logout all)
  static Future<void> clearAllTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (var key in keys) {
        if (key.startsWith(_accessTokenPrefix) ||
            key.startsWith(_refreshTokenPrefix) ||
            key.startsWith(_tokenExpiryPrefix)) {
          await prefs.remove(key);
        }
      }

      // Also clear current user email
      await prefs.remove(_currentUserEmailKey);

      debugPrint('🗑️ All tokens cleared for all users');
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing all tokens: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Get access token for current user
  static Future<String?> getCurrentUserAccessToken() async {
    final email = await getCurrentUserEmail();
    if (email == null) return null;
    return await getAccessToken(email);
  }

  /// Save tokens for current user (convenience method)
  static Future<void> saveCurrentUserTokens({
    required String accessToken,
    int? expiresInSeconds,
    String? refreshToken,
  }) async {
    final email = await getCurrentUserEmail();
    if (email == null) {
      debugPrint('❌ Cannot save tokens: No current user logged in');
      return;
    }

    await saveAccessToken(
      email: email,
      accessToken: accessToken,
      expiresInSeconds: expiresInSeconds,
      refreshToken: refreshToken,
    );
  }

  /// Get tokens for current user (convenience method)
  static Future<Map<String, String?>> getCurrentUserTokens() async {
    final email = await getCurrentUserEmail();
    if (email == null) return {};

    return {
      'accessToken': await getAccessToken(email),
      'refreshToken': await getRefreshToken(email),
    };
  }

  // ==================== Existing Notification Settings Methods ====================

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