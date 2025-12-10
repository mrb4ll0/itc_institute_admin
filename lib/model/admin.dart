import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  final String uid;
  final String fullName;
  final String email;
   String? photoUrl;
  final DateTime createdAt;
  final String role; // always "admin"

  Admin({
    required this.uid,
    required this.fullName,
    required this.email,
    this.photoUrl,
    DateTime? createdAt,
    this.role = 'admin',
  }) : createdAt = createdAt ?? DateTime.now();

  /// Construct from Firestore document data + doc ID
  factory Admin.fromMap(Map<String, dynamic> map, String uid) {
    return Admin(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      role: map['role'] as String? ?? 'admin',
    );
  }

  /// Convert to a plain map for `.set()` / `.update()`
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'role': role,
    };
  }

  @override
  String toString() {
    return 'Admin(uid: $uid, fullName: $fullName, email: $email, createdAt: $createdAt)';
  }
}
