import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import '../../model/notificationModel.dart';
import '../../model/student.dart';

class FireStoreNotification {
  // General notifications collection
  final CollectionReference generalNotificationsRef = FirebaseFirestore.instance
      .collection('notifications');

  // Students collection reference
  final CollectionReference studentsRef = FirebaseFirestore.instance
      .collection('users')
      .doc('students')
      .collection('students');

  // Get general notifications
  Future<List<NotificationModel>> getGeneralNotifications() async {
    final snapshot = await generalNotificationsRef
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      data['type'] = 'general'; // Add type identifier
      return NotificationModel.fromMap(data);
    }).toList();
  }

  // Get notifications for a specific student
  Future<List<NotificationModel>> getStudentNotifications(
    String studentUid,
  ) async {
    final snapshot = await studentsRef
        .doc(studentUid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      data['type'] = 'private'; // Add type identifier
      return NotificationModel.fromMap(data);
    }).toList();
  }

  // Get all notifications (general + student-specific) for a student
  Future<List<NotificationModel>> getAllNotificationsForStudent(
    String studentUid,
  ) async {
    final generalNotifications = await getGeneralNotifications();
    final studentNotifications = await getStudentNotifications(studentUid);

    return [...generalNotifications, ...studentNotifications]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Send general notification to all students
  Future<void> sendGeneralNotification({
    required String title,
    required String body,
    String? imageUrl,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      action: action,
      data: data,
      type: 'general',
      targetAudience:
          'all_students', // Can be: all_students, specific_department, etc.
    );

    await generalNotificationsRef
        .doc(notification.id)
        .set(notification.toMap());
  }

  // Send notification to a specific student
  Future<void> sendNotificationToStudent({
    required String studentUid,
    required String title,
    required String body,
    String? status, // For private notifications
    String? message, // For private notifications
    String? imageUrl,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      action: action,
      data: data,
      type: 'private',
      targetStudentId: studentUid,
    );

    await studentsRef
        .doc(studentUid)
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toMap());
  }

  // Send notification to multiple students
  Future<void> sendNotificationToStudents({
    required List<String> studentUids,
    required String title,
    required String body,
    String? status,
    String? message,
    String? imageUrl,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final studentUid in studentUids) {
      final notification = NotificationModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_$studentUid',
        title: title,
        body: body,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
        action: action,
        data: data,
        type: 'private',
        targetStudentId: studentUid,
      );

      final docRef = studentsRef
          .doc(studentUid)
          .collection('notifications')
          .doc(notification.id);

      batch.set(docRef, notification.toMap());
    }

    await batch.commit();
  }

  // Send tweet-related notifications
  Future<void> sendTweetNotification({
    required String tweetId,
    required String tweetContent,
    required Student sender,
    required String receiverUid,
    required NotificationType type,
    String? commentContent,
    String? replyContent,
  }) async {
    String title = '';
    String body = '';
    Map<String, dynamic> data = {
      'tweetId': tweetId,
      'tweetContent': tweetContent,
      'senderId': sender.uid,
      'senderName': sender.fullName,
      'notificationType': type.toString(),
    };

    switch (type) {
      case NotificationType.tweetLike:
        title = 'New Like on Your Tweet';
        body =
            '${sender.fullName} liked your tweet: "${tweetContent.substring(0, min(50, tweetContent.length))}..."';
        break;
      case NotificationType.tweetComment:
        title = 'New Comment on Your Tweet';
        body =
            '${sender.fullName} commented on your tweet: "${commentContent?.substring(0, min(50, commentContent!.length))}..."';
        data['commentContent'] = commentContent;
        break;
      case NotificationType.commentReply:
        title = 'New Reply to Your Comment';
        body =
            '${sender.fullName} replied to your comment: "${replyContent?.substring(0, min(50, replyContent!.length))}..."';
        data['replyContent'] = replyContent;
        break;
      case NotificationType.tweetMention:
        title = 'You Were Mentioned';
        body = '${sender.fullName} mentioned you in a tweet';
        break;
      case NotificationType.commentMention:
        title = 'You Were Mentioned in a Comment';
        body = '${sender.fullName} mentioned you in a comment';
        break;
      case NotificationType.system:
        // TODO: Handle this case.
        throw UnimplementedError();
      case NotificationType.announcement:
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    await sendNotificationToStudent(
      studentUid: receiverUid,
      title: title,
      body: body,
      action: 'view_tweet',
      data: data,
    );
  }

  // Mark notification as read for a student
  Future<void> markAsRead(
    String studentUid,
    String notificationId,
    String type,
  ) async {
    if (type == 'private') {
      await studentsRef
          .doc(studentUid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } else {
      // For general notifications, we might want to track read status per user
      // This would require a different structure
    }
  }

  // Mark all notifications as read for a student
  Future<void> markAllAsRead(String studentUid) async {
    final snapshot = await studentsRef
        .doc(studentUid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Delete a notification
  Future<void> deleteNotification(
    String studentUid,
    String notificationId,
    String type,
  ) async {
    if (type == 'private') {
      await studentsRef
          .doc(studentUid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } else {
      // Only admins should delete general notifications
      // await generalNotificationsRef.doc(notificationId).delete();
    }
  }

  // Get unread notifications count for a student
  Future<int> getUnreadCount(String studentUid) async {
    final snapshot = await studentsRef
        .doc(studentUid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .count()
        .get();

    return snapshot.count??0;
  }

  // Get notification by ID (works for both types)
  Future<NotificationModel?> getNotificationById(
    String id, {
    String? type,
    String? studentUid,
  }) async {
    if (type == 'private' && studentUid != null) {
      final doc = await studentsRef
          .doc(studentUid)
          .collection('notifications')
          .doc(id)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['type'] = 'private';
        return NotificationModel.fromMap(data);
      }
    } else {
      final doc = await generalNotificationsRef.doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['type'] = 'general';
        return NotificationModel.fromMap(data);
      }
    }
    return null;
  }

  // Stream for general notifications
  Stream<List<NotificationModel>> get generalNotificationsStream {
    return generalNotificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['type'] = 'general';
            return NotificationModel.fromMap(data);
          }).toList(),
        );
  }

  // Stream for student notifications
  Stream<List<NotificationModel>> getStudentNotificationsStream(
    String studentUid,
  ) {
    return studentsRef
        .doc(studentUid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['type'] = 'private';
            return NotificationModel.fromMap(data);
          }).toList(),
        );
  }

  // Combined stream for all notifications
  Stream<List<NotificationModel>> getAllNotificationsStream(String studentUid) {
    return Rx.combineLatest2<
      List<NotificationModel>,
      List<NotificationModel>,
      List<NotificationModel>
    >(generalNotificationsStream, getStudentNotificationsStream(studentUid), (
      general,
      private,
    ) {
      final all = [...general, ...private];
      all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return all;
    });
  }
}

// Helper function to get minimum of two numbers
int min(int a, int b) => a < b ? a : b;

// Enum for notification types
enum NotificationType {
  tweetLike,
  tweetComment,
  commentReply,
  tweetMention,
  commentMention,
  system,
  announcement,
}
