import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../notification/firebase/Firebase_push_notifications.dart';

class NotificationSender {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  Future<void> sendNotification(
    String receiverID,
    String body,
    String type,
    String title,
  ) async {
    try {
      // This assumes your user structure is: users/{role}/{roleCollection}/{uid}
      // You'll need to detect which role the receiver has
      final fcmToken = await _getFcmTokenOfReceiver(receiverID);
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _notificationService.sendNotificationToUser(
          fcmToken: fcmToken,
          title: title,
          body: body,
        );
      }
    } catch (e) {
      debugPrint("Error sending FCM notification: $e");
    }
  }

  Future<String?> _getFcmTokenOfReceiver(String receiverID) async {
    final roles = ['students', 'companies'];
    for (final role in roles) {
      final doc = await _firebaseFirestore
          .collection('users')
          .doc(role)
          .collection(role)
          .doc(receiverID)
          .get();

      if (doc.exists) {
        return doc.data()?['fcmToken'];
      }
    }
    return null;
  }
}
