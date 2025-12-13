import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/notificationModel.dart';

class FireStoreNotification {
  final CollectionReference notificationsRef = FirebaseFirestore.instance
      .collection('notifications');

  Future<List<NotificationModel>> getNotifications() async {
    final snapshot = await notificationsRef.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Ensure 'id' is set from doc.id if not present
      data['id'] = doc.id;
      return NotificationModel.fromMap(data);
    }).toList();
  }

  Future<NotificationModel?> getNotificationById(String id) async {
    final doc = await notificationsRef.doc(id).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return NotificationModel.fromMap(data);
    }
    return null;
  }

  Future<void> sendNotification(NotificationModel notification) async {
    await notificationsRef.doc(notification.id).set(notification.toMap());
  }

  Future<void> deleteNotification(String id) async {
    await notificationsRef.doc(id).delete();
  }
}
