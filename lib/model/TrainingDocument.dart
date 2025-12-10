import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingDocument {
  String id;
  String title;
  String description;
  String url;
  String type; // 'contract', 'report', 'certificate', 'other'
  DateTime uploadDate;
  String uploadedBy; // Student ID or Supervisor ID

  TrainingDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.type,
    required this.uploadDate,
    required this.uploadedBy,
  });

  factory TrainingDocument.fromMap(Map<String, dynamic> map) {
    return TrainingDocument(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? '',
      uploadDate: (map['uploadDate'] as Timestamp).toDate(),
      uploadedBy: map['uploadedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'type': type,
      'uploadDate': Timestamp.fromDate(uploadDate),
      'uploadedBy': uploadedBy,
    };
  }
}
