// lib/model/moderation_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, company }

class ModerationUser {
  final String uid;
  final String email;
  final UserRole role;
  final DateTime registeredAt;
  final bool isBanned;
  final Map<String, dynamic> rawData;

  ModerationUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.registeredAt,
    required this.isBanned,
    required this.rawData,
  });

  factory ModerationUser.fromMap(
      Map<String, dynamic> map, String uid, UserRole role) {
    return ModerationUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      role: role,
      registeredAt:
      (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isBanned: map['isBanned'] as bool? ?? false,
      rawData: map,
    );
  }
}
