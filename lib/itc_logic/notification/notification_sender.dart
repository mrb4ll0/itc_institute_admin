import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';

import '../../model/localNotification.dart';
import '../../model/notificationModel.dart';
import '../../notification/firebase/Firebase_push_notifications.dart';
import 'notificationPanel/notificationPanelService.dart';

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


      //final fcmToken = await _getFcmTokenOfReceiver(receiverID);
      final usersInfo = await ITCFirebaseLogic(FirebaseAuth.instance.currentUser?.uid??"").getAllUserContactInfo(specificUserId: receiverID);

      if (usersInfo != null && usersInfo.isNotEmpty) {
        await _notificationService.sendNotificationToUser(
          fcmToken: usersInfo.first.fcmToken??"",
          title: title,
          body: body,
        );

        NotificationModel notification = NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          body: body,
          timestamp: DateTime.now(),
          read: false,
          targetAudience: usersInfo.first.email,
          targetStudentId: usersInfo.first.userId,
          fcmToken: usersInfo.first.fcmToken??"",
          type: NotificationType.studentMessage.name,
        );

        NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(
          notification,
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
