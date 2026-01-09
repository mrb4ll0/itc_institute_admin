import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart';

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

    final url = Uri.parse('https://sendpushnotification-aysosigsha-uc.a.run.app');
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token == null) return;

    final roles = ['students', 'companies'];
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
}
