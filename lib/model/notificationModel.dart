import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? imageUrl;
  final String? action; // e.g., 'view_tweet', 'open_profile'
  final Map<String, dynamic>? data;
  final String type; // 'general' or 'private'
  final String? targetStudentId;
  final String? targetAudience; // For general notifications
  final bool read;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.imageUrl,
    this.action,
    this.data,
    required this.type,
    this.targetStudentId,
    this.targetAudience,
    this.read = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? map['status'] ?? 'No Title',
      body: map['body'] ?? map['message'] ?? 'No Message',
      timestamp:
          (map['timestamp'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      imageUrl: map['imageUrl'],
      action: map['action'],
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      type: map['type'] ?? 'general',
      targetStudentId: map['targetStudentId'],
      targetAudience: map['targetAudience'],
      read: map['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'action': action,
      'data': data,
      'type': type,
      'targetStudentId': targetStudentId,
      'targetAudience': targetAudience,
      'read': read,
    };
  }
}
