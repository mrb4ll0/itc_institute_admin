import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final List<String> targetUserIds;
  final DateTime sentAt;
  final String? postedBy;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetUserIds,
    required this.sentAt,
    this.postedBy,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      targetUserIds: List<String>.from(map['targetUserIds'] ?? []),
      sentAt: (map['sentAt'] is Timestamp)
          ? (map['sentAt'] as Timestamp).toDate()
          : map['sentAt'] ?? DateTime.now(),
      postedBy: map['postedBy'],
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] ?? null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'targetUserIds': targetUserIds,
      'sentAt': Timestamp.fromDate(sentAt),
      if (postedBy != null) 'postedBy': postedBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }
}
