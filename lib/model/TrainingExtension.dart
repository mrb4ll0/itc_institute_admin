import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingExtension {
  String id;
  String reason;
  DateTime originalEndDate;
  DateTime newEndDate;
  DateTime requestDate;
  DateTime? approvalDate;
  String status; // 'pending', 'approved', 'rejected'
  String? approvedBy;
  String? comments;

  TrainingExtension({
    required this.id,
    required this.reason,
    required this.originalEndDate,
    required this.newEndDate,
    required this.requestDate,
    this.approvalDate,
    this.status = 'pending',
    this.approvedBy,
    this.comments,
  });

  factory TrainingExtension.fromMap(Map<String, dynamic> map) {
    return TrainingExtension(
      id: map['id'] ?? '',
      reason: map['reason'] ?? '',
      originalEndDate: (map['originalEndDate'] as Timestamp).toDate(),
      newEndDate: (map['newEndDate'] as Timestamp).toDate(),
      requestDate: (map['requestDate'] as Timestamp).toDate(),
      approvalDate: map['approvalDate'] != null
          ? (map['approvalDate'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'pending',
      approvedBy: map['approvedBy'],
      comments: map['comments'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reason': reason,
      'originalEndDate': Timestamp.fromDate(originalEndDate),
      'newEndDate': Timestamp.fromDate(newEndDate),
      'requestDate': Timestamp.fromDate(requestDate),
      'approvalDate': approvalDate != null
          ? Timestamp.fromDate(approvalDate!)
          : null,
      'status': status,
      'approvedBy': approvedBy,
      'comments': comments,
    };
  }
}
