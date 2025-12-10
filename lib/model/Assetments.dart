import 'package:cloud_firestore/cloud_firestore.dart';

class Assessment {
  String id;
  String type; // 'midterm', 'final', 'weekly', 'project'
  String title;
  DateTime date;
  double score;
  double maxScore;
  String? comments;
  String assessedBy; // Supervisor ID

  Assessment({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.score,
    required this.maxScore,
    this.comments,
    required this.assessedBy,
  });

  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      score: (map['score'] as num).toDouble(),
      maxScore: (map['maxScore'] as num).toDouble(),
      comments: map['comments'],
      assessedBy: map['assessedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'date': Timestamp.fromDate(date),
      'score': score,
      'maxScore': maxScore,
      'comments': comments,
      'assessedBy': assessedBy,
    };
  }
}
