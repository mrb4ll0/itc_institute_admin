import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:itc_institute_admin/migrationService/ui/migrationSettingsPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../itc_logic/idservice/globalIdService.dart';
import 'migrationService.dart';

class MigrationManager {
  static final MigrationManager _instance = MigrationManager._internal();
  factory MigrationManager() => _instance;
  MigrationManager._internal();

  static const String _prefLastMigrationDate = 'last_migration_date';
  static const String _prefLastWeeklyMigration = 'last_weekly_migration';
  static const String _prefLastScheduledMigration = 'last_scheduled_migration';
  static const String _prefScheduledTime = 'scheduled_migration_time';
  static const String _prefMigrationAttempts = 'migration_attempts';

  bool _isRunning = false;

  /// Main method to trigger migration
  Future<void> doMigration(MigrationTrigger trigger) async {
    // Prevent concurrent migrations
    if (_isRunning) {
      debugPrint('Migration already in progress, skipping...');
      return;
    }

    // Skip if no user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user logged in, skipping migration');
      return;
    }

    // Check if migration should run based on trigger type
    final shouldRun = await _shouldRunMigration(trigger);
    if (!shouldRun) {
      debugPrint('Migration skipped for trigger: $trigger');
      return;
    }

    _isRunning = true;

    final migrationService = MigrationService(GlobalIdService.firestoreId);

    try {
      debugPrint('Starting migration for trigger: $trigger');

      await migrationService.startMigration();

      // Record successful migration
      await _recordMigrationAttempt(trigger, success: true);

      debugPrint('Migration completed successfully for trigger: $trigger');
    } catch (e, s) {
      debugPrint("Migration failed with error: $e");
      debugPrintStack(stackTrace: s);

      // Record failed attempt
      await _recordMigrationAttempt(trigger, success: false);

      // Re-throw if needed for manual triggers
      if (trigger == MigrationTrigger.manual) {
        rethrow;
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Check if migration should run based on trigger and history
  Future<bool> _shouldRunMigration(MigrationTrigger trigger) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (trigger) {
      case MigrationTrigger.manual:
      // Always run manual migrations
        return true;

      case MigrationTrigger.everyLaunch:
      // Always run on every launch (but with debounce)
        return _shouldRunEveryLaunch(prefs);

      case MigrationTrigger.firstDailyLaunch:
        return _shouldRunFirstDaily(prefs, today);

      case MigrationTrigger.weekly:
        return _shouldRunWeekly(prefs, now);

      case MigrationTrigger.scheduled:
        return _shouldRunScheduled(prefs, now, today);
    }
  }

  bool _shouldRunEveryLaunch(SharedPreferences prefs) {
    // Add debounce to prevent running too frequently
    final lastRunTimestamp = prefs.getInt('last_every_launch_migration');
    if (lastRunTimestamp == null) return true;

    final lastRun = DateTime.fromMillisecondsSinceEpoch(lastRunTimestamp);
    final minutesSinceLastRun = DateTime.now().difference(lastRun).inMinutes;

    // Don't run more than once every 5 minutes
    return minutesSinceLastRun >= 5;
  }

  bool _shouldRunFirstDaily(SharedPreferences prefs, DateTime today) {
    final lastRunDate = prefs.getString(_prefLastMigrationDate);
    if (lastRunDate == null) return true;

    try {
      final lastRun = DateTime.parse(lastRunDate);
      final lastRunDay = DateTime(lastRun.year, lastRun.month, lastRun.day);

      // Run if last run was before today
      return lastRunDay.isBefore(today);
    } catch (e) {
      return true; // If parsing fails, run migration
    }
  }

  bool _shouldRunWeekly(SharedPreferences prefs, DateTime now) {
    final lastRunTimestamp = prefs.getInt(_prefLastWeeklyMigration);
    if (lastRunTimestamp == null) return true;

    try {
      final lastRun = DateTime.fromMillisecondsSinceEpoch(lastRunTimestamp);
      final daysSinceLastRun = now.difference(lastRun).inDays;

      return daysSinceLastRun >= 7;
    } catch (e) {
      return true;
    }
  }

  bool _shouldRunScheduled(SharedPreferences prefs, DateTime now, DateTime today) {
    final lastRunDate = prefs.getString(_prefLastScheduledMigration);
    if (lastRunDate == null) return true;

    try {
      final lastRun = DateTime.parse(lastRunDate);
      final lastRunDay = DateTime(lastRun.year, lastRun.month, lastRun.day);

      // Get scheduled time (default: 10:00 PM)
      final scheduledTime = prefs.getString(_prefScheduledTime) ?? '22:00';
      final timeParts = scheduledTime.split(':');
      final scheduledHour = int.parse(timeParts[0]);
      final scheduledMinute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      final scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        scheduledHour,
        scheduledMinute,
      );

      // Run if:
      // 1. Last run was before today, AND
      // 2. Current time is after or equal to scheduled time
      return lastRunDay.isBefore(today) && now.isAfter(scheduledDateTime);
    } catch (e) {
      return true;
    }
  }

  /// Record migration attempt in SharedPreferences
  Future<void> _recordMigrationAttempt(MigrationTrigger trigger, {required bool success}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Update last run date
    await prefs.setString(_prefLastMigrationDate, now.toIso8601String());

    // Update trigger-specific timestamps
    switch (trigger) {
      case MigrationTrigger.everyLaunch:
        await prefs.setInt('last_every_launch_migration', now.millisecondsSinceEpoch);
        break;
      case MigrationTrigger.weekly:
        await prefs.setInt(_prefLastWeeklyMigration, now.millisecondsSinceEpoch);
        break;
      case MigrationTrigger.scheduled:
        await prefs.setString(_prefLastScheduledMigration, now.toIso8601String());
        break;
      default:
        break;
    }

    // Log the attempt (optional, for debugging)
    final attempts = prefs.getStringList(_prefMigrationAttempts) ?? [];
    attempts.add('${now.toIso8601String()}|${trigger.name}|${success ? 'SUCCESS' : 'FAILED'}');

    // Keep only last 50 attempts
    while (attempts.length > 50) {
      attempts.removeAt(0);
    }

    await prefs.setStringList(_prefMigrationAttempts, attempts);
  }

  /// Get migration history (useful for debugging)
  Future<List<Map<String, dynamic>>> getMigrationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getStringList(_prefMigrationAttempts) ?? [];

    return attempts.map((entry) {
      final parts = entry.split('|');
      return {
        'timestamp': parts[0],
        'trigger': parts.length > 1 ? parts[1] : 'unknown',
        'status': parts.length > 2 ? parts[2] : 'unknown',
      };
    }).toList();
  }

  /// Set scheduled time (e.g., "22:00" for 10 PM)
  Future<void> setScheduledTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefScheduledTime, time);
  }

  /// Force reset migration tracking (useful for testing)
  Future<void> resetTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLastMigrationDate);
    await prefs.remove(_prefLastWeeklyMigration);
    await prefs.remove(_prefLastScheduledMigration);
    await prefs.remove('last_every_launch_migration');
  }
}