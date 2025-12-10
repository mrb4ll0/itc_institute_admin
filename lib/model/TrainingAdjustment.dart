import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingAdjustment {
  String id;
  String type; // 'schedule', 'supervisor', 'department', 'tasks'
  String description;
  DateTime requestDate;
  DateTime? approvalDate;
  String status; // 'pending', 'approved', 'rejected'
  String? approvedBy;
  String? comments;
  Map<String, dynamic> changes;

  TrainingAdjustment({
    required this.id,
    required this.type,
    required this.description,
    required this.requestDate,
    this.approvalDate,
    this.status = 'pending',
    this.approvedBy,
    this.comments,
    this.changes = const {},
  });

  factory TrainingAdjustment.fromMap(Map<String, dynamic> map) {
    return TrainingAdjustment(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      requestDate: (map['requestDate'] as Timestamp).toDate(),
      approvalDate: map['approvalDate'] != null
          ? (map['approvalDate'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'pending',
      approvedBy: map['approvedBy'],
      comments: map['comments'],
      changes: Map<String, dynamic>.from(map['changes'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'requestDate': Timestamp.fromDate(requestDate),
      'approvalDate': approvalDate != null
          ? Timestamp.fromDate(approvalDate!)
          : null,
      'status': status,
      'approvedBy': approvedBy,
      'comments': comments,
      'changes': changes,
    };
  }
}
