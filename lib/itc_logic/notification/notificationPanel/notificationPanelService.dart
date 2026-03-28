import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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
    debugPrint("sendNotificationToAllEnabledChannels");
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return {};

    debugPrint("sendNotificationToAllEnabledChannels");

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
debugPrint("channelsToSend is $channelsToSend");
    // Send to each channel and collect results
    Map<NotificationType, String?> results = {};

    for (var channel in channelsToSend) {
      debugPrint("channel in channel loop ${channel.displayName}");
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
    debugPrint("sendNotificationToAllEnabledChannelsWithSummary");
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
    debugPrint("channel is ${channel.displayName}");

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
    // Get all FCM tokens if targetAudience is not specified
    List<String> tokens = [];

    if (notification.targetAudience != null && notification.targetAudience!.isNotEmpty) {
      // Single user by ID
      if (notification.targetStudentId != null && notification.targetStudentId!.isNotEmpty) {
        tokens = [notification.fcmToken ?? ''];
      } else {
        // Get token by email or ID
        tokens = await _getFCMTokensByAudience(
          targetAudience: notification.targetAudience,
          studentId: notification.targetStudentId,
        );
      }
    } else {
      // Send to all users
      tokens = await _getAllFCMTokens();
    }

    // Remove null/empty tokens
    tokens = tokens.where((token) => token.isNotEmpty).toList();

    if (tokens.isEmpty) {
      return NotificationDeliveryStatus.failed.displayName;
    }

    // Send to all tokens
    bool allSent = true;
    for (var token in tokens) {
      bool isSent = await notificationService.sendNotificationToUser(
        fcmToken: token,
        title: notification.title,
        body: notification.body,
        data: notification.data,
      );
      if (!isSent) allSent = false;
    }

    NotificationDeliveryStatus status = allSent ? NotificationDeliveryStatus.sent : NotificationDeliveryStatus.failed;
    return status.displayName;
  }

  static Future<String?> _sendEmailNotification(NotificationModel notification) async {
    // Get all emails
    List<String> allEmails = [];

    if (notification.targetAudience != null && notification.targetAudience!.isNotEmpty) {
      allEmails = [notification.targetAudience!];
    } else if (notification.targetStudentId != null && notification.targetStudentId!.isNotEmpty) {
      String? email = await _getEmailByUserId(notification.targetStudentId!);
      if (email != null) allEmails = [email];
    } else {
      allEmails = await _getAllEmails();
    }

    if (allEmails.isEmpty) {
      return NotificationDeliveryStatus.failed.displayName;
    }

    // Split into batches of 50 recipients per batch (SMTP limit is typically 100)
    const int batchSize = 50;
    bool allSent = true;

    for (int i = 0; i < allEmails.length; i += batchSize) {
      int end = (i + batchSize < allEmails.length) ? i + batchSize : allEmails.length;
      List<String> batch = allEmails.sublist(i, end);

      // Send to batch
      bool batchSent = await notificationService.sendEmail(
        to: batch.join(','), // Join emails with commas
        subject: notification.title,
        body: notification.body,
      );

      if (!batchSent) allSent = false;

      // Add delay between batches to avoid rate limiting
      if (i + batchSize < allEmails.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    NotificationDeliveryStatus status = allSent ? NotificationDeliveryStatus.sent : NotificationDeliveryStatus.failed;
    return status.displayName;
  }


  static String _truncateSubject(String subject) {
    // SMTP subject line limit is typically 998 characters (RFC 5322)
    const int maxSubjectLength = 200; // Conservative limit
    if (subject.length <= maxSubjectLength) return subject;
    return '${subject.substring(0, maxSubjectLength - 3)}...';
  }

  static Future<String?> _sendSmsNotification(NotificationModel notification) async {
    // SMS implementation will be added here
    // Get phone numbers by user ID or email if needed
    return null;
  }

  static Future<String?> _sendInAppNotification(NotificationModel notification) async {
    // Determine target user ID
    String? targetUid = notification.targetStudentId ?? notification.targetAudience;

    if (targetUid == null || targetUid.isEmpty) {
      // Send to all users if no specific target
      await _sendInAppNotificationToAll(notification);
      return NotificationDeliveryStatus.sent.displayName;
    }

    // Send to specific user
    await fireStoreNotification.sendNotificationToStudent(
      studentUid: targetUid,
      fcmToken: notification.fcmToken,
      title: notification.title,
      imageUrl: notification.imageUrl,
      body: notification.body,
    );
    return NotificationDeliveryStatus.sent.displayName;
  }

  // Helper methods for fetching contact information
  static Future<List<String>> _getFCMTokensByAudience({
    String? targetAudience,
    String? studentId,
  }) async {
    List<String> tokens = [];

    try {
      if (studentId != null && studentId.isNotEmpty) {
        // Get token by user ID
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();

        if (userDoc.exists) {
          final token = userDoc.data()?['fcmToken'] as String?;
          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      } else if (targetAudience != null && targetAudience.isNotEmpty) {
        // Check if targetAudience is an email
        if (targetAudience.contains('@')) {
          // Get token by email
          final querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: targetAudience)
              .get();

          for (var doc in querySnapshot.docs) {
            final token = doc.data()['fcmToken'] as String?;
            if (token != null && token.isNotEmpty) {
              tokens.add(token);
            }
          }
        } else {
          // Treat as user ID
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(targetAudience)
              .get();

          if (userDoc.exists) {
            final token = userDoc.data()?['fcmToken'] as String?;
            if (token != null && token.isNotEmpty) {
              tokens.add(token);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting FCM tokens by audience: $e');
    }

    return tokens;
  }

  static Future<List<String>> _getAllFCMTokens() async {
    List<String> allTokens = [];

    try {
      // Get all users with FCM tokens
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          allTokens.add(token);
        }
      }

      // Also check admins collection if exists
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .get();

      for (var doc in adminsSnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          allTokens.add(token);
        }
      }

      allTokens = allTokens.toSet().toList(); // Remove duplicates
      debugPrint('✅ Retrieved ${allTokens.length} FCM tokens');
    } catch (e) {
      debugPrint('Error getting all FCM tokens: $e');
    }

    return allTokens;
  }

  static Future<List<String>> _getAllEmails() async {
    List<String> allEmails = [];

    try {
      // Get all users with emails
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String?;
        if (email != null && email.isNotEmpty) {
          allEmails.add(email);
        }
      }

      // Also check admins collection if exists
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .get();

      for (var doc in adminsSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String?;
        if (email != null && email.isNotEmpty) {
          allEmails.add(email);
        }
      }

      allEmails = allEmails.toSet().toList(); // Remove duplicates
      debugPrint('✅ Retrieved ${allEmails.length} emails');
    } catch (e) {
      debugPrint('Error getting all emails: $e');
    }

    return allEmails;
  }

  static Future<String?> _getEmailByUserId(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return userDoc.data()?['email'] as String?;
      }
    } catch (e) {
      debugPrint('Error getting email by user ID: $e');
    }

    return null;
  }

  static Future<void> _sendInAppNotificationToAll(NotificationModel notification) async {
    // Send to all students/users
    // Implementation depends on your FireStoreNotification service
    // You might need to add a method like sendNotificationToAllUsers
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var doc in usersSnapshot.docs) {
        await fireStoreNotification.sendNotificationToStudent(
          studentUid: doc.id,
          fcmToken: notification.fcmToken,
          title: notification.title,
          imageUrl: notification.imageUrl,
          body: notification.body,
        );
      }
    } catch (e) {
      debugPrint('Error sending in-app notification to all: $e');
    }
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