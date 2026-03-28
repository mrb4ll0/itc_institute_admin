import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart' hide NotificationType;
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';
import 'package:itc_institute_admin/model/notificationModel.dart';

import '../../../model/notificationSettingModel.dart';
import '../../localDB/sharedPreference.dart';

class NotificationPanelService {
  static final notificationService = NotificationService();
  static final fireStoreNotification = FireStoreNotification();

  // Original method - sends notification through the appropriate channel based on type
  static Future<String?> sendNotification(
      NotificationType type,
      NotificationModel notification,
      ) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return null;

    final settings = await UserPreferences.getNotificationSettings(user.email!);

    if (!settings.hasAnyEnabledInCategory(NotificationCategory.channels)) return null;

    // Check if the specific notification type is enabled
    if (!settings.isEnabled(type)) return null;

    // Send using the appropriate channel
    return await _sendByNotificationType(type, notification);
  }

  // NEW METHOD: Send notification through all enabled channels
  static Future<Map<NotificationType, String?>> sendNotificationToAllEnabledChannels(
      NotificationModel notification, {
        List<NotificationType>? specificChannels, // Optional: specify which channels to send to
      }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return {};

    final settings = await UserPreferences.getNotificationSettings(user.email!);

    // Define the channel types (these are the NotificationType values that represent channels)
    const channelTypes = [
      NotificationType.push,
      NotificationType.email,
      NotificationType.sms,
      NotificationType.inApp,
    ];

    // Determine which channels to send to
    List<NotificationType> channelsToSend = specificChannels ??
        channelTypes.where((channel) => settings.isEnabled(channel)).toList();

    // Send to each channel and collect results
    Map<NotificationType, String?> results = {};

    for (var channel in channelsToSend) {
      if (settings.isEnabled(channel)) {
        String? result = await _sendByNotificationType(channel, notification);
        results[channel] = result;
      } else {
        results[channel] = null; // Channel not enabled
      }
    }

    return results;
  }

  // Alternative: Send through all enabled channels and return summary
  static Future<MultiChannelDeliveryResult> sendNotificationToAllEnabledChannelsWithSummary(
      NotificationModel notification,
      ) async {
    Map<NotificationType, String?> results = await sendNotificationToAllEnabledChannels(notification);

    int sentCount = results.values.where((status) =>
    status != null && status == NotificationDeliveryStatus.sent.displayName
    ).length;

    int failedCount = results.values.where((status) =>
    status != null && status == NotificationDeliveryStatus.failed.displayName
    ).length;

    int disabledCount = results.values.where((status) => status == null).length;

    return MultiChannelDeliveryResult(
      results: results,
      sentCount: sentCount,
      failedCount: failedCount,
      disabledCount: disabledCount,
      isFullySuccessful: sentCount > 0 && failedCount == 0,
      isPartiallySuccessful: sentCount > 0 && failedCount > 0,
    );
  }

  // Send notification through a specific channel (NotificationType)
  static Future<String?> sendNotificationViaChannel(
      NotificationType channel,
      NotificationModel notification,
      ) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return null;

    final settings = await UserPreferences.getNotificationSettings(user.email!);

    // Check if the channel is enabled
    if (!settings.isEnabled(channel)) return null;

    // Send using the channel
    return await _sendByNotificationType(channel, notification);
  }

  // Core method that handles sending for any NotificationType
  static Future<String?> _sendByNotificationType(
      NotificationType type,
      NotificationModel notification,
      ) async {
    // Check if this is a channel type
    if (_isChannelType(type)) {
      return await _sendViaChannel(type, notification);
    }

    // For non-channel types (trainee alerts, system, reminders), route to appropriate channel
    // By default, these go to in-app notifications
    return await _sendViaChannel(NotificationType.inApp, notification);
  }

  // Check if a NotificationType is a channel
  static bool _isChannelType(NotificationType type) {
    return type == NotificationType.push ||
        type == NotificationType.email ||
        type == NotificationType.sms ||
        type == NotificationType.inApp;
  }

  // Send via specific channel
  static Future<String?> _sendViaChannel(
      NotificationType channel,
      NotificationModel notification,
      ) async {
    switch (channel) {
      case NotificationType.push:
        return await _sendPushNotification(notification);

      case NotificationType.email:
        return await _sendEmailNotification(notification);

      case NotificationType.sms:
        return await _sendSmsNotification(notification);

      case NotificationType.inApp:
        return await _sendInAppNotification(notification);

      default:
        return null;
    }
  }

  // Individual channel send methods
  static Future<String?> _sendPushNotification(NotificationModel notification) async {
    bool isSent = await notificationService.sendNotificationToUser(
      fcmToken: notification.fcmToken,
      title: notification.title,
      body: notification.body,
      data: notification.data,
    );
    NotificationDeliveryStatus status = isSent ? NotificationDeliveryStatus.sent : NotificationDeliveryStatus.failed;
    return status.displayName;
  }

  static Future<String?> _sendEmailNotification(NotificationModel notification) async {
    bool isSent = await notificationService.sendEmail(
      to: notification.targetAudience ?? "",
      subject: notification.title,
      body: notification.body,
    );
    NotificationDeliveryStatus status = isSent ? NotificationDeliveryStatus.sent : NotificationDeliveryStatus.failed;
    return status.displayName;
  }

  static Future<String?> _sendSmsNotification(NotificationModel notification) async {
    // SMS implementation will be added here
    // For now, return null or implement your SMS logic
    return null;
  }

  static Future<String?> _sendInAppNotification(NotificationModel notification) async {
    await fireStoreNotification.sendNotificationToStudent(
      studentUid: notification.targetAudience ?? "",
      fcmToken: notification.fcmToken,
      title: notification.title,
      imageUrl: notification.imageUrl,
      body: notification.body,
    );
    return NotificationDeliveryStatus.sent.displayName;
  }
}

// Result class for multi-channel delivery
class MultiChannelDeliveryResult {
  final Map<NotificationType, String?> results;
  final int sentCount;
  final int failedCount;
  final int disabledCount;
  final bool isFullySuccessful;
  final bool isPartiallySuccessful;

  MultiChannelDeliveryResult({
    required this.results,
    required this.sentCount,
    required this.failedCount,
    required this.disabledCount,
    required this.isFullySuccessful,
    required this.isPartiallySuccessful,
  });

  @override
  String toString() {
    return 'MultiChannelDeliveryResult(sent: $sentCount, failed: $failedCount, disabled: $disabledCount)';
  }
}