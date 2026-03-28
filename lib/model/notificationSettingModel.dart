import 'package:flutter/material.dart';


enum NotificationType {
  // Notification Channels
  push,
  email,
  sms,
  inApp,

  // Trainee & Application Alerts
  newTraineeApplications,
  formSubmissions,
  traineeUpdates,
  applicationStatus,

  // System Notifications
  systemUpdates,
  maintenanceAlerts,
  securityAlerts,

  // Reminders
  dailyReminders,
  pendingFormsReminders,
  profileCompletionReminders,
}

// Extension for display names and categories
extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
    // Channels
      case NotificationType.push:
        return 'Push Notifications';
      case NotificationType.email:
        return 'Email Notifications';
      case NotificationType.sms:
        return 'SMS Notifications';
      case NotificationType.inApp:
        return 'In-App Notifications';

    // Trainee Alerts
      case NotificationType.newTraineeApplications:
        return 'New Trainee Applications';
      case NotificationType.formSubmissions:
        return 'Form Submissions';
      case NotificationType.traineeUpdates:
        return 'Trainee Updates';
      case NotificationType.applicationStatus:
        return 'Application Status';

    // System Alerts
      case NotificationType.systemUpdates:
        return 'System Updates';
      case NotificationType.maintenanceAlerts:
        return 'Maintenance Alerts';
      case NotificationType.securityAlerts:
        return 'Security Alerts';

    // Reminders
      case NotificationType.dailyReminders:
        return 'Daily Reminders';
      case NotificationType.pendingFormsReminders:
        return 'Pending Forms Reminders';
      case NotificationType.profileCompletionReminders:
        return 'Profile Completion Reminders';
    }
  }

  NotificationCategory get category {
    switch (this) {
      case NotificationType.push:
      case NotificationType.email:
      case NotificationType.sms:
      case NotificationType.inApp:
        return NotificationCategory.channels;

      case NotificationType.newTraineeApplications:
      case NotificationType.formSubmissions:
      case NotificationType.traineeUpdates:
      case NotificationType.applicationStatus:
        return NotificationCategory.trainee;

      case NotificationType.systemUpdates:
      case NotificationType.maintenanceAlerts:
      case NotificationType.securityAlerts:
        return NotificationCategory.system;

      case NotificationType.dailyReminders:
      case NotificationType.pendingFormsReminders:
      case NotificationType.profileCompletionReminders:
        return NotificationCategory.reminders;
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.push:
        return Icons.notifications_active;
      case NotificationType.email:
        return Icons.email;
      case NotificationType.sms:
        return Icons.sms;
      case NotificationType.inApp:
        return Icons.notifications;
      case NotificationType.newTraineeApplications:
        return Icons.person_add;
      case NotificationType.formSubmissions:
        return Icons.assignment;
      case NotificationType.traineeUpdates:
        return Icons.people;
      case NotificationType.applicationStatus:
        return Icons.assessment;
      case NotificationType.systemUpdates:
        return Icons.system_update;
      case NotificationType.maintenanceAlerts:
        return Icons.build;
      case NotificationType.securityAlerts:
        return Icons.security;
      case NotificationType.dailyReminders:
        return Icons.today;
      case NotificationType.pendingFormsReminders:
        return Icons.pending_actions;
      case NotificationType.profileCompletionReminders:
        return Icons.person;
    }
  }
}

enum NotificationCategory {
  channels,
  trainee,
  system,
  reminders,
}

extension NotificationCategoryExtension on NotificationCategory {
  String get displayName {
    switch (this) {
      case NotificationCategory.channels:
        return 'Notification Channels';
      case NotificationCategory.trainee:
        return 'Trainee & Application Alerts';
      case NotificationCategory.system:
        return 'System Notifications';
      case NotificationCategory.reminders:
        return 'Reminders';
    }
  }
}

enum NotificationDeliveryStatus {
  pending,    // Queued to be sent
  sent,       // Successfully sent
  delivered,  // Delivered to device/email
  read,       // User has read/seen it
  failed,     // Failed to send
  cancelled,  // Cancelled before sending
}

extension NotificationDeliveryStatusExtension on NotificationDeliveryStatus {
  String get displayName {
    switch (this) {
      case NotificationDeliveryStatus.pending:
        return 'Pending';
      case NotificationDeliveryStatus.sent:
        return 'Sent';
      case NotificationDeliveryStatus.delivered:
        return 'Delivered';
      case NotificationDeliveryStatus.read:
        return 'Read';
      case NotificationDeliveryStatus.failed:
        return 'Failed';
      case NotificationDeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationDeliveryStatus.pending:
        return Icons.pending;
      case NotificationDeliveryStatus.sent:
        return Icons.send;
      case NotificationDeliveryStatus.delivered:
        return Icons.check_circle;
      case NotificationDeliveryStatus.read:
        return Icons.mark_email_read;
      case NotificationDeliveryStatus.failed:
        return Icons.error;
      case NotificationDeliveryStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class NotificationSettings {

  final Map<NotificationType, bool> enabledNotifications;
  // Quiet Hours
  final bool quietHoursEnabled;
  final TimeOfDay quietStartTime;
  final TimeOfDay quietEndTime;
  // Sound & Vibration
  final bool soundEnabled;
  final bool vibrationEnabled;

  NotificationSettings({
    required this.enabledNotifications,
    required this.quietHoursEnabled,
    required this.quietStartTime,
    required this.quietEndTime,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  // Create default settings
  factory NotificationSettings.defaultSettings() {
    return NotificationSettings(
      enabledNotifications: {
        // Channels
        NotificationType.push: true,
        NotificationType.email: true,
        NotificationType.sms: false,
        NotificationType.inApp: true,

        // Trainee Alerts
        NotificationType.newTraineeApplications: true,
        NotificationType.formSubmissions: true,
        NotificationType.traineeUpdates: true,
        NotificationType.applicationStatus: true,

        // System Alerts
        NotificationType.systemUpdates: true,
        NotificationType.maintenanceAlerts: false,
        NotificationType.securityAlerts: true,

        // Reminders
        NotificationType.dailyReminders: false,
        NotificationType.pendingFormsReminders: true,
        NotificationType.profileCompletionReminders: true,
      },
      quietHoursEnabled: false,
      quietStartTime: const TimeOfDay(hour: 22, minute: 0),
      quietEndTime: const TimeOfDay(hour: 8, minute: 0),
      soundEnabled: true,
      vibrationEnabled: true,
    );
  }

  // Helper methods for working with enums
  bool isEnabled(NotificationType type) {
    return enabledNotifications[type] ?? false;
  }

  void setEnabled(NotificationType type, bool enabled) {
    enabledNotifications[type] = enabled;
  }

  List<NotificationType> getEnabledTypes() {
    return enabledNotifications.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  List<NotificationType> getEnabledTypesByCategory(NotificationCategory category) {
    return enabledNotifications.entries
        .where((entry) => entry.value && entry.key.category == category)
        .map((entry) => entry.key)
        .toList();
  }

  bool hasAnyEnabledInCategory(NotificationCategory category) {
    return enabledNotifications.entries
        .any((entry) => entry.value && entry.key.category == category);
  }

  int getEnabledCountByCategory(NotificationCategory category) {
    return enabledNotifications.entries
        .where((entry) => entry.value && entry.key.category == category)
        .length;
  }


  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'enabledNotifications': enabledNotifications.map(
              (key, value) => MapEntry(key.name, value)
      ),
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

    Map<NotificationType, bool> enabledNotifications = {};
    if (map['enabledNotifications'] != null) {
      (map['enabledNotifications'] as Map).forEach((key, value) {
        try {
          enabledNotifications[NotificationType.values.firstWhere(
                  (e) => e.name == key
          )] = value as bool;
        } catch (e) {
          // Handle unknown notification types
        }
      });
    }

    return NotificationSettings(
      enabledNotifications: enabledNotifications,
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
    Map<NotificationType, bool>? enabledNotifications,
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
      enabledNotifications: enabledNotifications ?? Map.from(this.enabledNotifications),
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartTime: quietStartTime ?? this.quietStartTime,
      quietEndTime: quietEndTime ?? this.quietEndTime,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
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






  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.quietHoursEnabled == quietHoursEnabled &&
        other.quietStartTime == quietStartTime &&
        other.quietEndTime == quietEndTime &&
        other.soundEnabled == soundEnabled &&
        other.vibrationEnabled == vibrationEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      quietHoursEnabled,
      quietStartTime,
      quietEndTime,
      soundEnabled,
      vibrationEnabled,
    );
  }

  NotificationSettings toggleNotification(NotificationType type) {
    final newSettings = Map<NotificationType, bool>.from(enabledNotifications);
    newSettings[type] = !(newSettings[type] ?? false);
    return copyWith(enabledNotifications: newSettings);
  }

  // Enable/disable all notifications in a category
  NotificationSettings setCategoryEnabled(NotificationCategory category, bool enabled) {
    final newSettings = Map<NotificationType, bool>.from(enabledNotifications);
    for (var type in NotificationType.values) {
      if (type.category == category) {
        newSettings[type] = enabled;
      }
    }
    return copyWith(enabledNotifications: newSettings);
  }

  // Enable/disable all notifications
  NotificationSettings setAllNotificationsEnabled(bool enabled) {
    final newSettings = Map<NotificationType, bool>.from(enabledNotifications);
    for (var type in NotificationType.values) {
      newSettings[type] = enabled;
    }
    return copyWith(enabledNotifications: newSettings);
  }
}


