import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingLog {
  String id;
  DateTime date;
  String category; // 'task', 'meeting', 'learning', 'issue'
  String description;
  String? notes;
  List<String> attachedFiles;
  String loggedBy; // Student or Supervisor ID

  TrainingLog({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    this.notes,
    this.attachedFiles = const [],
    required this.loggedBy,
  });

  factory TrainingLog.fromMap(Map<String, dynamic> map) {
    return TrainingLog(
      id: map['id'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      notes: map['notes'],
      attachedFiles: List<String>.from(map['attachedFiles'] ?? []),
      loggedBy: map['loggedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'category': category,
      'description': description,
      'notes': notes,
      'attachedFiles': attachedFiles,
      'loggedBy': loggedBy,
    };
  }
}
