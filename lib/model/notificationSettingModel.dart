import 'package:flutter/material.dart';

class NotificationSettings {
  // Notification Channels
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool inAppNotifications;

  // Trainee & Application Alerts
  final bool newTraineeApplications;
  final bool formSubmissions;
  final bool traineeUpdates;
  final bool applicationStatus;

  // System Notifications
  final bool systemUpdates;
  final bool maintenanceAlerts;
  final bool securityAlerts;

  // Reminders
  final bool dailyReminders;
  final bool pendingFormsReminders;
  final bool profileCompletionReminders;

  // Quiet Hours
  final bool quietHoursEnabled;
  final TimeOfDay quietStartTime;
  final TimeOfDay quietEndTime;

  // Sound & Vibration
  final bool soundEnabled;
  final bool vibrationEnabled;

  NotificationSettings({
    required this.pushNotifications,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.inAppNotifications,
    required this.newTraineeApplications,
    required this.formSubmissions,
    required this.traineeUpdates,
    required this.applicationStatus,
    required this.systemUpdates,
    required this.maintenanceAlerts,
    required this.securityAlerts,
    required this.dailyReminders,
    required this.pendingFormsReminders,
    required this.profileCompletionReminders,
    required this.quietHoursEnabled,
    required this.quietStartTime,
    required this.quietEndTime,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  // Create default settings
  factory NotificationSettings.defaultSettings() {
    return NotificationSettings(
      pushNotifications: true,
      emailNotifications: true,
      smsNotifications: false,
      inAppNotifications: true,
      newTraineeApplications: true,
      formSubmissions: true,
      traineeUpdates: true,
      applicationStatus: true,
      systemUpdates: true,
      maintenanceAlerts: false,
      securityAlerts: true,
      dailyReminders: false,
      pendingFormsReminders: true,
      profileCompletionReminders: true,
      quietHoursEnabled: false,
      quietStartTime: const TimeOfDay(hour: 22, minute: 0),
      quietEndTime: const TimeOfDay(hour: 8, minute: 0),
      soundEnabled: true,
      vibrationEnabled: true,
    );
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      // Notification Channels
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'inAppNotifications': inAppNotifications,

      // Trainee & Application Alerts
      'newTraineeApplications': newTraineeApplications,
      'formSubmissions': formSubmissions,
      'traineeUpdates': traineeUpdates,
      'applicationStatus': applicationStatus,

      // System Notifications
      'systemUpdates': systemUpdates,
      'maintenanceAlerts': maintenanceAlerts,
      'securityAlerts': securityAlerts,

      // Reminders
      'dailyReminders': dailyReminders,
      'pendingFormsReminders': pendingFormsReminders,
      'profileCompletionReminders': profileCompletionReminders,

      // Quiet Hours
      'quietHoursEnabled': quietHoursEnabled,
      'quietStartHour': quietStartTime.hour,
      'quietStartMinute': quietStartTime.minute,
      'quietEndHour': quietEndTime.hour,
      'quietEndMinute': quietEndTime.minute,

      // Sound & Vibration
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  // Create from Map
  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      pushNotifications: map['pushNotifications'] ?? true,
      emailNotifications: map['emailNotifications'] ?? true,
      smsNotifications: map['smsNotifications'] ?? false,
      inAppNotifications: map['inAppNotifications'] ?? true,
      newTraineeApplications: map['newTraineeApplications'] ?? true,
      formSubmissions: map['formSubmissions'] ?? true,
      traineeUpdates: map['traineeUpdates'] ?? true,
      applicationStatus: map['applicationStatus'] ?? true,
      systemUpdates: map['systemUpdates'] ?? true,
      maintenanceAlerts: map['maintenanceAlerts'] ?? false,
      securityAlerts: map['securityAlerts'] ?? true,
      dailyReminders: map['dailyReminders'] ?? false,
      pendingFormsReminders: map['pendingFormsReminders'] ?? true,
      profileCompletionReminders: map['profileCompletionReminders'] ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] ?? false,
      quietStartTime: TimeOfDay(
        hour: map['quietStartHour'] ?? 22,
        minute: map['quietStartMinute'] ?? 0,
      ),
      quietEndTime: TimeOfDay(
        hour: map['quietEndHour'] ?? 8,
        minute: map['quietEndMinute'] ?? 0,
      ),
      soundEnabled: map['soundEnabled'] ?? true,
      vibrationEnabled: map['vibrationEnabled'] ?? true,
    );
  }

  // Create a copy with updated values
  NotificationSettings copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? inAppNotifications,
    bool? newTraineeApplications,
    bool? formSubmissions,
    bool? traineeUpdates,
    bool? applicationStatus,
    bool? systemUpdates,
    bool? maintenanceAlerts,
    bool? securityAlerts,
    bool? dailyReminders,
    bool? pendingFormsReminders,
    bool? profileCompletionReminders,
    bool? quietHoursEnabled,
    TimeOfDay? quietStartTime,
    TimeOfDay? quietEndTime,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      inAppNotifications: inAppNotifications ?? this.inAppNotifications,
      newTraineeApplications: newTraineeApplications ?? this.newTraineeApplications,
      formSubmissions: formSubmissions ?? this.formSubmissions,
      traineeUpdates: traineeUpdates ?? this.traineeUpdates,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      systemUpdates: systemUpdates ?? this.systemUpdates,
      maintenanceAlerts: maintenanceAlerts ?? this.maintenanceAlerts,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      pendingFormsReminders: pendingFormsReminders ?? this.pendingFormsReminders,
      profileCompletionReminders: profileCompletionReminders ?? this.profileCompletionReminders,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartTime: quietStartTime ?? this.quietStartTime,
      quietEndTime: quietEndTime ?? this.quietEndTime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  // Check if any notifications are enabled
  bool get hasAnyNotificationsEnabled {
    return pushNotifications ||
        emailNotifications ||
        smsNotifications ||
        inAppNotifications;
  }

  // Check if quiet hours are currently active
  bool isQuietHoursActive(DateTime now) {
    if (!quietHoursEnabled) return false;

    final currentTime = TimeOfDay.fromDateTime(now);

    // Handle quiet hours that span midnight
    if (quietStartTime.hour > quietEndTime.hour ||
        (quietStartTime.hour == quietEndTime.hour &&
            quietStartTime.minute > quietEndTime.minute)) {
      // Quiet hours span across midnight
      return currentTime.hour >= quietStartTime.hour ||
          currentTime.hour < quietEndTime.hour ||
          (currentTime.hour == quietEndTime.hour &&
              currentTime.minute < quietEndTime.minute);
    } else {
      // Normal quiet hours within same day
      final startMinutes = quietStartTime.hour * 60 + quietStartTime.minute;
      final endMinutes = quietEndTime.hour * 60 + quietEndTime.minute;
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;

      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }

  // Get summary of enabled notification types
  List<String> getEnabledNotificationTypes() {
    final enabled = <String>[];
    if (pushNotifications) enabled.add('Push');
    if (emailNotifications) enabled.add('Email');
    if (smsNotifications) enabled.add('SMS');
    if (inAppNotifications) enabled.add('In-App');
    return enabled;
  }

  // Get count of enabled notification categories
  Map<String, int> getEnabledCategoriesCount() {
    return {
      'channels': [
        pushNotifications,
        emailNotifications,
        smsNotifications,
        inAppNotifications
      ].where((e) => e).length,
      'trainee': [
        newTraineeApplications,
        formSubmissions,
        traineeUpdates,
        applicationStatus
      ].where((e) => e).length,
      'system': [
        systemUpdates,
        maintenanceAlerts,
        securityAlerts
      ].where((e) => e).length,
      'reminders': [
        dailyReminders,
        pendingFormsReminders,
        profileCompletionReminders
      ].where((e) => e).length,
    };
  }

  @override
  String toString() {
    return 'NotificationSettings(\n'
        '  pushNotifications: $pushNotifications,\n'
        '  emailNotifications: $emailNotifications,\n'
        '  smsNotifications: $smsNotifications,\n'
        '  inAppNotifications: $inAppNotifications,\n'
        '  newTraineeApplications: $newTraineeApplications,\n'
        '  formSubmissions: $formSubmissions,\n'
        '  traineeUpdates: $traineeUpdates,\n'
        '  applicationStatus: $applicationStatus,\n'
        '  systemUpdates: $systemUpdates,\n'
        '  maintenanceAlerts: $maintenanceAlerts,\n'
        '  securityAlerts: $securityAlerts,\n'
        '  dailyReminders: $dailyReminders,\n'
        '  pendingFormsReminders: $pendingFormsReminders,\n'
        '  profileCompletionReminders: $profileCompletionReminders,\n'
        '  quietHoursEnabled: $quietHoursEnabled,\n'
        '  quietStartTime: ${quietStartTime.format(const Locale('en') as BuildContext)},\n'
        '  quietEndTime: ${quietEndTime.format(const Locale('en') as BuildContext)},\n'
        '  soundEnabled: $soundEnabled,\n'
        '  vibrationEnabled: $vibrationEnabled,\n'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.pushNotifications == pushNotifications &&
        other.emailNotifications == emailNotifications &&
        other.smsNotifications == smsNotifications &&
        other.inAppNotifications == inAppNotifications &&
        other.newTraineeApplications == newTraineeApplications &&
        other.formSubmissions == formSubmissions &&
        other.traineeUpdates == traineeUpdates &&
        other.applicationStatus == applicationStatus &&
        other.systemUpdates == systemUpdates &&
        other.maintenanceAlerts == maintenanceAlerts &&
        other.securityAlerts == securityAlerts &&
        other.dailyReminders == dailyReminders &&
        other.pendingFormsReminders == pendingFormsReminders &&
        other.profileCompletionReminders == profileCompletionReminders &&
        other.quietHoursEnabled == quietHoursEnabled &&
        other.quietStartTime == quietStartTime &&
        other.quietEndTime == quietEndTime &&
        other.soundEnabled == soundEnabled &&
        other.vibrationEnabled == vibrationEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      pushNotifications,
      emailNotifications,
      smsNotifications,
      inAppNotifications,
      newTraineeApplications,
      formSubmissions,
      traineeUpdates,
      applicationStatus,
      systemUpdates,
      maintenanceAlerts,
      securityAlerts,
      dailyReminders,
      pendingFormsReminders,
      profileCompletionReminders,
      quietHoursEnabled,
      quietStartTime,
      quietEndTime,
      soundEnabled,
      vibrationEnabled,
    );
  }
}