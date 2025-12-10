import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingTask {
  String id;
  String title;
  String description;
  DateTime deadline;
  bool isCompleted;
  DateTime? completedDate;
  String? notes;
  int priority; // 1-5, where 5 is highest

  TrainingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    this.isCompleted = false,
    this.completedDate,
    this.notes,
    this.priority = 3,
  });

  factory TrainingTask.fromMap(Map<String, dynamic> map) {
    return TrainingTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      deadline: (map['deadline'] as Timestamp).toDate(),
      isCompleted: map['isCompleted'] ?? false,
      completedDate: map['completedDate'] != null
          ? (map['completedDate'] as Timestamp).toDate()
          : null,
      notes: map['notes'],
      priority: map['priority'] ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'isCompleted': isCompleted,
      'completedDate': completedDate != null
          ? Timestamp.fromDate(completedDate!)
          : null,
      'notes': notes,
      'priority': priority,
    };
  }
}
