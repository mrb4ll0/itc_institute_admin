import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyReport {
  String id;
  int weekNumber;
  DateTime startDate;
  DateTime endDate;
  String tasksCompleted;
  String challenges;
  String learnings;
  String plansForNextWeek;
  DateTime submittedDate;
  String? supervisorFeedback;
  DateTime? feedbackDate;

  WeeklyReport({
    required this.id,
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.tasksCompleted,
    required this.challenges,
    required this.learnings,
    required this.plansForNextWeek,
    required this.submittedDate,
    this.supervisorFeedback,
    this.feedbackDate,
  });

  factory WeeklyReport.fromMap(Map<String, dynamic> map) {
    return WeeklyReport(
      id: map['id'] ?? '',
      weekNumber: map['weekNumber'] ?? 0,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      tasksCompleted: map['tasksCompleted'] ?? '',
      challenges: map['challenges'] ?? '',
      learnings: map['learnings'] ?? '',
      plansForNextWeek: map['plansForNextWeek'] ?? '',
      submittedDate: (map['submittedDate'] as Timestamp).toDate(),
      supervisorFeedback: map['supervisorFeedback'],
      feedbackDate: map['feedbackDate'] != null
          ? (map['feedbackDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekNumber': weekNumber,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'tasksCompleted': tasksCompleted,
      'challenges': challenges,
      'learnings': learnings,
      'plansForNextWeek': plansForNextWeek,
      'submittedDate': Timestamp.fromDate(submittedDate),
      'supervisorFeedback': supervisorFeedback,
      'feedbackDate': feedbackDate != null
          ? Timestamp.fromDate(feedbackDate!)
          : null,
    };
  }
}
