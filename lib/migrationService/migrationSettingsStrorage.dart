import 'package:itc_institute_admin/migrationService/ui/migrationSettingsPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class MigrationSettingsStorage {
  static const String _keyTrigger = 'migration_trigger';
  static const String _keyWifiOnly = 'migration_wifi_only';
  static const String _keyWhileCharging = 'migration_while_charging';
  static const String _keyShowNotifications = 'migration_show_notifications';
  static const String _keyScheduledHour = 'migration_scheduled_hour';
  static const String _keyScheduledMinute = 'migration_scheduled_minute';
  static const String _keyWeeklyDay = 'migration_weekly_day';

  // Save all settings
  static Future<void> saveSettings({
    required MigrationTrigger trigger,
    required bool wifiOnly,
    required bool whileCharging,
    required bool showNotifications,
    TimeOfDay? scheduledTime,
    int? weeklyDay,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyTrigger, trigger.name);
    await prefs.setBool(_keyWifiOnly, wifiOnly);
    await prefs.setBool(_keyWhileCharging, whileCharging);
    await prefs.setBool(_keyShowNotifications, showNotifications);

    if (scheduledTime != null) {
      await prefs.setInt(_keyScheduledHour, scheduledTime.hour);
      await prefs.setInt(_keyScheduledMinute, scheduledTime.minute);
    }

    if (weeklyDay != null) {
      await prefs.setInt(_keyWeeklyDay, weeklyDay);
    }

    debugPrint("✅ Migration settings saved: ${trigger.name}");
  }

  // Load all settings
  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final triggerName = prefs.getString(_keyTrigger) ?? MigrationTrigger.firstDailyLaunch.name;
    final trigger = MigrationTrigger.values.firstWhere(
          (e) => e.name == triggerName,
      orElse: () => MigrationTrigger.firstDailyLaunch,
    );

    final wifiOnly = prefs.getBool(_keyWifiOnly) ?? true;
    final whileCharging = prefs.getBool(_keyWhileCharging) ?? false;
    final showNotifications = prefs.getBool(_keyShowNotifications) ?? true;

    final scheduledHour = prefs.getInt(_keyScheduledHour);
    final scheduledMinute = prefs.getInt(_keyScheduledMinute);
    TimeOfDay? scheduledTime;
    if (scheduledHour != null && scheduledMinute != null) {
      scheduledTime = TimeOfDay(hour: scheduledHour, minute: scheduledMinute);
    }

    final weeklyDay = prefs.getInt(_keyWeeklyDay) ?? DateTime.monday;

    return {
      'trigger': trigger,
      'wifiOnly': wifiOnly,
      'whileCharging': whileCharging,
      'showNotifications': showNotifications,
      'scheduledTime': scheduledTime,
      'weeklyDay': weeklyDay,
    };
  }

  // Clear all settings
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint("✅ Migration settings cleared");
  }
}