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
  // Add these constants at the top of the UserPreferences class with the other static constants
  static const String _lockedAccountPrefix = "locked_account_";
  static const String _lockDurationPrefix = "lock_duration_";
  static const String _lockExpiryPrefix = "lock_expiry_";
  static const String _lockReasonPrefix = "lock_reason_";

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

  // ==================== Account Lock Management Methods ====================

  /// Lock a user account with optional duration
  /// [email] - User's email address
  /// [duration] - Duration to lock the account (null for permanent lock)
  /// [reason] - Reason for locking the account
  /// [lockedBy] - Admin or system that locked the account
  static Future<bool> lockAccount({
    required String email,
    Duration? duration, // null means permanent lock
    String? reason,
    String? lockedBy,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockKey = _lockedAccountPrefix + email;

      // Mark account as locked
      await prefs.setBool(lockKey, true);

      // Save lock reason if provided
      if (reason != null) {
        final reasonKey = _lockReasonPrefix + email;
        await prefs.setString(reasonKey, reason);
      }

      // Save lock duration and expiry if provided
      if (duration != null) {
        final durationKey = _lockDurationPrefix + email;
        await prefs.setInt(durationKey, duration.inSeconds);

        final expiryTime = DateTime.now().add(duration);
        final expiryKey = _lockExpiryPrefix + email;
        await prefs.setString(expiryKey, expiryTime.toIso8601String());

        debugPrint('🔒 Account locked for $email until: $expiryTime');
      } else {
        debugPrint('🔒 Account permanently locked for $email');
      }

      // Optional: Save who locked the account
      if (lockedBy != null) {
        final lockedByKey = "${_lockedAccountPrefix}by_$email";
        await prefs.setString(lockedByKey, lockedBy);
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error locking account: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if an account is locked
  /// Returns true if locked and still within lock period, false otherwise
  static Future<bool> isAccountLocked(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockKey = _lockedAccountPrefix + email;
      final isLocked = prefs.getBool(lockKey) ?? false;

      if (!isLocked) return false;

      // Check if lock has expired
      final isExpired = await isLockExpired(email);
      if (isExpired) {
        // Auto-unlock if expired
        await unlockAccount(email, autoUnlock: true);
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking account lock: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if the lock period has expired
  static Future<bool> isLockExpired(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryKey = _lockExpiryPrefix + email;
      final expiryString = prefs.getString(expiryKey);

      if (expiryString == null) return false; // Permanent lock or no expiry

      final expiryTime = DateTime.parse(expiryString);
      final isExpired = DateTime.now().isAfter(expiryTime);

      if (isExpired) {
        debugPrint('🔓 Lock expired for $email at: $expiryTime');
      }

      return isExpired;
    } catch (e) {
      debugPrint('❌ Error checking lock expiry: $e');
      return false;
    }
  }

  /// Get lock expiry time
  static Future<DateTime?> getLockExpiryTime(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryKey = _lockExpiryPrefix + email;
      final expiryString = prefs.getString(expiryKey);

      if (expiryString == null) return null;
      return DateTime.parse(expiryString);
    } catch (e) {
      debugPrint('❌ Error getting lock expiry: $e');
      return null;
    }
  }

  /// Get time remaining until account is unlocked (in seconds)
  /// Returns null for permanent locks or if account is not locked
  static Future<int?> getRemainingLockTime(String email) async {
    final isLocked = await isAccountLocked(email);
    if (!isLocked) return null;

    final expiryTime = await getLockExpiryTime(email);
    if (expiryTime == null) return null; // Permanent lock

    final remainingSeconds = expiryTime.difference(DateTime.now()).inSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  /// Get formatted remaining lock time as string
  static Future<String?> getFormattedRemainingLockTime(String email) async {
    final remainingSeconds = await getRemainingLockTime(email);
    if (remainingSeconds == null) return null;
    if (remainingSeconds <= 0) return "0 seconds";

    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }

  /// Get lock reason
  static Future<String?> getLockReason(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reasonKey = _lockReasonPrefix + email;
      return prefs.getString(reasonKey);
    } catch (e) {
      debugPrint('❌ Error getting lock reason: $e');
      return null;
    }
  }

  /// Unlock an account
  /// [autoUnlock] - Set to true if this is an automatic unlock from expiry
  static Future<bool> unlockAccount(String email, {bool autoUnlock = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove all lock-related data
      await prefs.remove(_lockedAccountPrefix + email);
      await prefs.remove(_lockDurationPrefix + email);
      await prefs.remove(_lockExpiryPrefix + email);
      await prefs.remove(_lockReasonPrefix + email);
      await prefs.remove("${_lockedAccountPrefix}by_$email");

      if (autoUnlock) {
        debugPrint('🔓 Account automatically unlocked for $email (lock period expired)');
      } else {
        debugPrint('🔓 Account manually unlocked for $email');
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error unlocking account: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Update lock duration for an already locked account
  static Future<bool> updateLockDuration({
    required String email,
    required Duration newDuration,
    String? newReason,
  }) async {
    try {
      // Check if account is locked
      final isLocked = await isAccountLocked(email);
      if (!isLocked) {
        debugPrint('⚠️ Cannot update lock duration: Account $email is not locked');
        return false;
      }

      // Update with new duration
      final prefs = await SharedPreferences.getInstance();
      final durationKey = _lockDurationPrefix + email;
      await prefs.setInt(durationKey, newDuration.inSeconds);

      final newExpiryTime = DateTime.now().add(newDuration);
      final expiryKey = _lockExpiryPrefix + email;
      await prefs.setString(expiryKey, newExpiryTime.toIso8601String());

      // Update reason if provided
      if (newReason != null) {
        final reasonKey = _lockReasonPrefix + email;
        await prefs.setString(reasonKey, newReason);
      }

      debugPrint('🕐 Lock duration updated for $email. New expiry: $newExpiryTime');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating lock duration: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Get lock status details for an account
  static Future<Map<String, dynamic>> getLockStatus(String email) async {
    try {
      final isLocked = await isAccountLocked(email);

      if (!isLocked) {
        return {
          'isLocked': false,
          'message': 'Account is not locked',
        };
      }

      final expiryTime = await getLockExpiryTime(email);
      final remainingSeconds = await getRemainingLockTime(email);
      final reason = await getLockReason(email);
      final isPermanent = expiryTime == null;

      return {
        'isLocked': true,
        'isPermanent': isPermanent,
        'expiryTime': expiryTime,
        'remainingSeconds': remainingSeconds,
        'formattedRemainingTime': await getFormattedRemainingLockTime(email),
        'reason': reason ?? 'No reason provided',
        'message': isPermanent
            ? 'Account is permanently locked'
            : 'Account is locked for ${await getFormattedRemainingLockTime(email)}',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting lock status: $e');
      debugPrintStack(stackTrace: stackTrace);
      return {'isLocked': false, 'error': e.toString()};
    }
  }

  /// Get all locked accounts (useful for admin dashboard)
  static Future<List<Map<String, dynamic>>> getAllLockedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final lockedAccounts = <Map<String, dynamic>>[];

      for (var key in keys) {
        if (key.startsWith(_lockedAccountPrefix) && !key.contains('by_')) {
          final email = key.substring(_lockedAccountPrefix.length);
          final isLocked = await isAccountLocked(email);

          if (isLocked) {
            final lockStatus = await getLockStatus(email);
            lockedAccounts.add({
              'email': email,
              ...lockStatus,
            });
          }
        }
      }

      return lockedAccounts;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting locked accounts: $e');
      debugPrintStack(stackTrace: stackTrace);
      return [];
    }
  }

  /// Auto-check and unlock expired locks (call this periodically, e.g., on app start)
  static Future<void> autoUnlockExpiredLocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int unlockedCount = 0;

      for (var key in keys) {
        if (key.startsWith(_lockedAccountPrefix) && !key.contains('by_')) {
          final email = key.substring(_lockedAccountPrefix.length);
          final isExpired = await isLockExpired(email);

          if (isExpired) {
            await unlockAccount(email, autoUnlock: true);
            unlockedCount++;
          }
        }
      }

      if (unlockedCount > 0) {
        debugPrint('🔓 Auto-unlocked $unlockedCount expired account(s)');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error auto-unlocking expired locks: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Clear all lock data (admin use only)
  static Future<void> clearAllLocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (var key in keys) {
        if (key.startsWith(_lockedAccountPrefix) ||
            key.startsWith(_lockDurationPrefix) ||
            key.startsWith(_lockExpiryPrefix) ||
            key.startsWith(_lockReasonPrefix)) {
          await prefs.remove(key);
        }
      }

      debugPrint('🗑️ All account locks cleared');
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing all locks: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}