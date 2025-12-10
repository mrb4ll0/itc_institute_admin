import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingMilestone {
  String id;
  String title;
  String description;
  DateTime dueDate;
  bool isCompleted;
  DateTime? completedDate;
  List<String> requiredDocuments;

  TrainingMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.completedDate,
    this.requiredDocuments = const [],
  });

  factory TrainingMilestone.fromMap(Map<String, dynamic> map) {
    return TrainingMilestone(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      isCompleted: map['isCompleted'] ?? false,
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      requiredDocuments: List<String>.from(map['requiredDocuments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'isCompleted': isCompleted,
      'completedDate': completedDate != null
          ? Timestamp.fromDate(completedDate!)
          : null,
      'requiredDocuments': requiredDocuments,
    };
  }
}
