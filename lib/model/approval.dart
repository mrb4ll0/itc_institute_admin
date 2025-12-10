// lib/model/approval.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalType { student, company, agent }

class Approval {
  final String id;
  final ApprovalType type;
  final String name;
  final DateTime submittedAt;
  final Map<String, dynamic> rawData;

  Approval({
    required this.id,
    required this.type,
    required this.name,
    required this.submittedAt,
    required this.rawData,
  });

  factory Approval.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final typeString = data['type'] as String? ?? 'student';

    // more explicit mapping for safety:
    ApprovalType type;
    switch (typeString) {
      case 'company':
        type = ApprovalType.company;
        break;
      case 'agent':
        type = ApprovalType.agent;
        break;
      case 'student':
      default:
        type = ApprovalType.student;
    }

    return Approval(
      id: doc.id,
      type: type,
      name: data['name'] as String? ?? 'Unknown',
      submittedAt:
      (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rawData: data,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.toString().split('.').last,
    'name': name,
    'submittedAt': Timestamp.fromDate(submittedAt),
    ...rawData,
  };
}
