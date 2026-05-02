import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:itc_institute_admin/itc_logic/localDB/sharedPreference.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server/gmail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/authService/authService.dart';
import '../idservice/globalIdService.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  void Function(Map<String, dynamic>)? _onNotificationTap;

  void setOnNotificationTapHandler(
    void Function(Map<String, dynamic>) handler,
  ) {
    _onNotificationTap = handler;
  }

  /// 🔔 Initialize everything
  Future<void> init() async {
    await _requestPermission();
    await _configureToken();
    await _initLocalNotifications();
    _initForegroundMessageListener();
    _initOnMessageOpenedApp();
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _configureToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final settings = InitializationSettings(android: androidSettings);
    await _flutterLocalNotificationsPlugin.initialize(settings);
  }

  void _initForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(notification.title, notification.body);
      }
    });
  }

  void _initOnMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      debugPrint("App opened from notification with data: $data");
      if (_onNotificationTap != null) {
        _onNotificationTap!(data);
      }
    });
  }

  static Future<void> backgroundHandler(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await NotificationService()._showLocalNotification(
        notification.title,
        notification.body,
      );
    }
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    const androidDetails = AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  // ...existing code...
  Future<bool> sendNotificationToUser({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {

    final url = Uri.parse('https://sendpushnotification-6nik2g7gkq-uc.a.run.app');//production
    //final url = Uri.parse('https://sendpushnotification-aysosigsha-uc.a.run.app');//dev environment
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('Notification sent successfully');
      return true;
    } else {
      debugPrint('Failed to send notification: ${response.body}');
      return false;
    }
  }
  // ...existing code...

  // /// 🚨 TEMPORARY — Send a notification using your server key (dangerous for prod!)
  // Future<void> sendNotificationToUser({
  //   required String recipientToken,
  //   required String title,
  //   required String body,
  //   required String type, // e.g., "chat", "booking_accepted"
  //   Map<String, dynamic>? extraData,
  // }) async {
  //   final url = Uri.parse(uri);
  //   final data = {
  //     "to": recipientToken,
  //     "notification": {
  //       "title": title,
  //       "body": body,
  //     },
  //     "data": {
  //       "click_action": "FLUTTER_NOTIFICATION_CLICK",
  //       "type": type,
  //       ...?extraData,
  //     },
  //     "priority": "high",
  //   };

  //   try {
  //     final response = await http.post(
  //       Uri.parse('https://fcm.googleapis.com/fcm/send'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'key=BEDn_pEBMow9fHlFK6DBWAB4eQwCHuHpazERFzd6Bd7sodtOVu6YI09-H9YAK3KmSrxWP1EWMYxzSbeO8Z5eTwc', // 🔥 Replace temporarily
  //       },
  //       body: json.encode(data),
  //     );
  //     if (response.statusCode == 200) {
  //       debugPrint("Notification sent successfully");
  //     } else {
  //       debugPrint("Failed to send notification: ${response.body}");
  //     }
  //   } catch (e) {
  //     debugPrint("Error sending notification: $e");
  //   }
  // }

  /// 💾 Save FCM token to the correct user document
  Future<void> saveTokenToFirestore() async {
    final token = await FirebaseMessaging.instance.getToken();
    final uid = GlobalIdService.firestoreId;
    if (uid == null || token == null) return;

    final roles = ['companies','authorities'];
    for (final role in roles) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(role)
          .collection(role)
          .doc(uid);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        await docRef.update({'fcmToken': token});
        break;
      }
    }
  }



  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? fromEmail,
    String? fromName,
    bool isHtml = false,
    List<mailer.Attachment>? attachments,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    try {
      // Get current user for authentication
      // final user = FirebaseAuth.instance.currentUser;
      // if (user == null) {
      //   debugPrint('No authenticated user found to send email');
      //   return false;
      // }
  debugPrint("to is $to and subject is $subject and body is $body and fromEmail is $fromEmail and fromName is $fromName");

      final accessToken = "vmwq lbjy huaa tula";
      final email = "im511569@gmail.com";
        if(accessToken == null)
          {
            return false;
          }
      debugPrint("access token is $accessToken");
      if (accessToken == null) {
        debugPrint('Failed to get access token for email sending');
        return false;
      }

      // Configure SMTP server with OAuth2
      // debugPrint("email is ${user.email} ");
      final smtpServer = gmail(email, accessToken);

      // Build email message
      final message = mailer.Message()
        ..from = mailer.Address(
        'itconnect010@gmail.com',
          fromName ?? 'IT Connect',
        )
        ..recipients.add(to)
        ..subject = subject
        ..text = isHtml ? null : body
        ..html = isHtml ? body : null;

      // Add attachments if provided
      if (attachments != null && attachments.isNotEmpty) {
        message.attachments.addAll(attachments);
      }

      // Send email with timeout
  debugPrint("send Email with timeout");
      await mailer.send(message, smtpServer).timeout(timeout);

      debugPrint('Email sent successfully to $to');
      return true;

    } on TimeoutException {
      debugPrint('Email sending timed out after ${timeout.inSeconds} seconds');
      return false;
    } catch (e) {
      debugPrint('Failed to send email: $e');
      return false;
    }
  }

  /// 📧 Send email with rich HTML template
  Future<bool> sendRichEmail({
    required String to,
    required String subject,
    required String title,
    required String content,
    String? buttonText,
    String? buttonUrl,
    String? footerText,
    String? fromEmail,
    String? fromName,
    List<mailer.Attachment>? attachments,
  }) async {
    final htmlBody = _buildEmailTemplate(
      title: title,
      content: content,
      buttonText: buttonText,
      buttonUrl: buttonUrl,
      footerText: footerText,
    );

    return await sendEmail(
      to: to,
      subject: subject,
      body: htmlBody,
      fromEmail: fromEmail,
      fromName: fromName,
      isHtml: true,
      attachments: attachments,
    );
  }

  /// 📧 Send application confirmation email
  Future<bool> sendApplicationConfirmationEmail({
    required String studentEmail,
    required String studentName,
    required String companyName,
    required String internshipTitle,
    required String applicationId,
    Map<String, dynamic>? details,
  }) async {
    final subject = 'Application Confirmation: $internshipTitle';

    // Extract values first
    final startDate = details != null ? details['startDate'] : null;
    final duration = details != null ? details['duration'] : null;

    final content = '''
    <p>Dear $studentName,</p>
    
    <p>Your application for the <strong>$internshipTitle</strong> position at <strong>$companyName</strong> has been successfully submitted.</p>
    
    <p><strong>Application Details:</strong></p>
    <ul>
      <li><strong>Application ID:</strong> $applicationId</li>
      <li><strong>Company:</strong> $companyName</li>
      <li><strong>Position:</strong> $internshipTitle</li>
      ${startDate != null ? '<li><strong>Proposed Start Date:</strong> $startDate</li>' : ''}
      ${duration != null ? '<li><strong>Preferred Duration:</strong> $duration</li>' : ''}
    </ul>
    
    <p>The company will review your application and contact you if they wish to proceed.</p>
    
    <p>Best regards,<br/>IT Connect Team</p>
  ''';

    return await sendRichEmail(
      to: studentEmail,
      subject: subject,
      title: 'Application Submitted Successfully!',
      content: content,
      buttonText: 'View Application',
      buttonUrl: 'https://itconnect.com/applications/$applicationId',
      footerText: 'This is an automated message, please do not reply.',
    );
  }


  /// 📧 Send notification to company about new application
  Future<bool> sendNewApplicationNotificationEmail({
    required String companyEmail,
    required String companyName,
    required String studentName,
    required String studentEmail,
    required String internshipTitle,
    required Map<String, dynamic> applicationDetails,
  }) async {
    final subject = 'New Application: $internshipTitle';
    final content = '''
      <p>Dear $companyName,</p>
      
      <p>A new application has been submitted for the <strong>$internshipTitle</strong> position.</p>
      
      <p><strong>Applicant Details:</strong></p>
      <ul>
        <li><strong>Name:</strong> $studentName</li>
        <li><strong>Email:</strong> $studentEmail</li>
        <li><strong>Preferred Duration:</strong> ${applicationDetails['duration'] ?? 'Not specified'}</li>
        <li><strong>Proposed Start Date:</strong> ${applicationDetails['startDate'] ?? 'Not specified'}</li>
      </ul>
      
      <p>Please log in to your dashboard to review the full application and attached documents.</p>
      
      <p>Best regards,<br/>IT Connect Team</p>
    ''';

    return await sendRichEmail(
      to: companyEmail,
      subject: subject,
      title: 'New Application Received!',
      content: content,
      buttonText: 'Review Application',
      buttonUrl: 'https://itconnect.com/company/dashboard',
      footerText: 'This is an automated notification.',
    );
  }

  /// 📧 Send password reset email
  Future<bool> sendPasswordResetEmail({
    required String to,
    required String name,
    required String resetLink,
  }) async {
    final subject = 'Password Reset Request';
    final content = '''
      <p>Dear $name,</p>
      
      <p>We received a request to reset your password. Click the button below to create a new password:</p>
      
      <p style="text-align: center;">
        <a href="$resetLink" style="display: inline-block; padding: 12px 24px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 4px;">
          Reset Password
        </a>
      </p>
      
      <p>If you didn't request this, please ignore this email. This link will expire in 24 hours.</p>
      
      <p>Best regards,<br/>IT Connect Team</p>
    ''';

    return await sendRichEmail(
      to: to,
      subject: subject,
      title: 'Password Reset Request',
      content: content,
      footerText: 'For security reasons, do not share this email with anyone.',
    );
  }

  /// 📧 Send welcome email to new user
  Future<bool> sendWelcomeEmail({
    required String to,
    required String name,
    required String role, // 'student', 'company', or 'authority'
  }) async {
    final subject = 'Welcome to IT Connect!';

    String roleSpecificContent = '';
    if (role == 'student') {
      roleSpecificContent = '''
        <p>As a student, you can:</p>
        <ul>
          <li>Browse and apply for internship opportunities</li>
          <li>Track your application status</li>
          <li>Upload your documents for future applications</li>
          <li>Receive notifications about new opportunities</li>
        </ul>
      ''';
    } else if (role == 'company') {
      roleSpecificContent = '''
        <p>As a company, you can:</p>
        <ul>
          <li>Post internship opportunities</li>
          <li>Review and manage applications</li>
          <li>Communicate with potential candidates</li>
          <li>Track your hiring process</li>
        </ul>
      ''';
    } else {
      roleSpecificContent = '''
        <p>As an authority, you can:</p>
        <ul>
          <li>Monitor internship applications</li>
          <li>Verify and approve internship programs</li>
          <li>Generate reports and analytics</li>
          <li>Manage system settings</li>
        </ul>
      ''';
    }

    final content = '''
      <p>Dear $name,</p>
      
      <p>Welcome to IT Connect! We're excited to have you on board.</p>
      
      $roleSpecificContent
      
      <p>To get started, please complete your profile and explore the platform.</p>
      
      <p>If you have any questions, feel free to contact our support team.</p>
      
      <p>Best regards,<br/>IT Connect Team</p>
    ''';

    return await sendRichEmail(
      to: to,
      subject: subject,
      title: 'Welcome to IT Connect! 🎉',
      content: content,
      buttonText: 'Get Started',
      buttonUrl: 'https://itconnect.com/dashboard',
      footerText: 'We\'re here to help you succeed!',
    );
  }

  /// 📧 Send bulk emails (with rate limiting)
  Future<Map<String, dynamic>> sendBulkEmails({
    required List<String> recipients,
    required String subject,
    required String body,
    bool isHtml = false,
    int batchSize = 10,
    Duration delayBetweenBatches = const Duration(seconds: 2),
  }) async {
    int successCount = 0;
    int failureCount = 0;
    List<String> failedRecipients = [];

    for (int i = 0; i < recipients.length; i += batchSize) {
      final end = (i + batchSize < recipients.length) ? i + batchSize : recipients.length;
      final batch = recipients.sublist(i, end);

      // Send batch concurrently with type-safe results
      final List<Map<String, dynamic>> results = await Future.wait(
        batch.map((recipient) async {
          final success = await sendEmail(
            to: recipient,
            subject: subject,
            body: body,
            isHtml: isHtml,
          );
          return {'recipient': recipient, 'success': success};
        }).toList(),
      );

      // Count results with proper type checking
      for (var result in results) {
        final recipient = result['recipient'] as String;
        final success = result['success'] as bool;

        if (success) {
          successCount++;
        } else {
          failureCount++;
          failedRecipients.add(recipient);
        }
      }

      // Wait before next batch to avoid rate limiting
      if (i + batchSize < recipients.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }

    return {
      'total': recipients.length,
      'success': successCount,
      'failure': failureCount,
      'failedRecipients': failedRecipients,
    };
  }


  /// 📧 Send email using EmailJS (alternative method)
  Future<bool> sendEmailViaEmailJS({
    required String to,
    required String subject,
    required String body,
    required String serviceId,
    required String templateId,
    required String userId,
    String? accessToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'accessToken': accessToken,
          'template_params': {
            'to_email': to,
            'subject': subject,
            'message': body,
            // Add more template parameters as needed
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Email sent successfully via EmailJS');
        return true;
      } else {
        debugPrint('Failed to send email via EmailJS: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending email via EmailJS: $e');
      return false;
    }
  }

  /// 🎨 Build HTML email template
  String _buildEmailTemplate({
    required String title,
    required String content,
    String? buttonText,
    String? buttonUrl,
    String? footerText,
  }) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .header {
            background-color: #4CAF50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px 5px 0 0;
          }
          .content {
            background-color: #f9f9f9;
            padding: 30px;
            border-radius: 0 0 5px 5px;
          }
          .button {
            display: inline-block;
            padding: 12px 24px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin: 20px 0;
          }
          .footer {
            text-align: center;
            padding: 20px;
            font-size: 12px;
            color: #666;
            border-top: 1px solid #eee;
            margin-top: 20px;
          }
          @media only screen and (max-width: 600px) {
            .container {
              width: 100%;
              padding: 10px;
            }
            .content {
              padding: 20px;
            }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h2>$title</h2>
          </div>
          <div class="content">
            $content
            ${buttonText != null && buttonUrl != null ? '''
            <div style="text-align: center;">
              <a href="$buttonUrl" class="button">$buttonText</a>
            </div>
            ''' : ''}
            ${footerText != null ? '''
            <div class="footer">
              $footerText
            </div>
            ''' : ''}
          </div>
        </div>
      </body>
      </html>
    ''';
  }
}

/// 📎 Attachment model for emails
class EmailAttachment {
  final String name;
  final List<int> bytes;
  final String? mimeType;

  EmailAttachment({
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  factory EmailAttachment.fromFile(File file, {String? mimeType}) {
    return EmailAttachment(
      name: file.path.split('/').last,
      bytes: file.readAsBytesSync(),
      mimeType: mimeType,
    );
  }

  factory EmailAttachment.fromString(String name, String content, {String? mimeType}) {
    return EmailAttachment(
      name: name,
      bytes: utf8.encode(content),
      mimeType: mimeType ?? 'text/plain',
    );
  }

  mailer.Attachment toMailerAttachment() {
    // Try to decode bytes as string for text files
    try {
      final stringContent = utf8.decode(bytes);
      return mailer.StringAttachment(
        stringContent,
        contentType: mimeType ?? 'text/plain',
        fileName: name,
      );
    } catch (e) {
      // If it's not a valid UTF-8 string, use StreamAttachment for binary data
      return mailer.StreamAttachment(
        Stream.fromIterable([bytes]),
        mimeType ?? 'application/octet-stream',
        fileName: name,
      );
    }
  }
}