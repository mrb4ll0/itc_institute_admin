import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _userPrefix = "user_"; // key prefix per email

  /// Save user data after signup or login
  static Future<void> saveUser(Map<String, dynamic> userMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = userMap['email'];
      if (email == null) throw Exception(
          'User map must contain an email field.');


      final key = _userPrefix + email;

      final jsonString = jsonEncode(userMap);

      await prefs.setString(key, jsonString);
    }catch(e, stackTrace)
    {
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

  /// Clear user data (optional utility)
  static Future<void> clearUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _userPrefix + email;
    await prefs.remove(key);
  }
}
