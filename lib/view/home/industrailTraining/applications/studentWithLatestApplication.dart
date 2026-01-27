import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../model/student.dart';
import '../../../../model/studentApplication.dart';

class StudentWithLatestApplication {
  final Student student;
  final StudentApplication? latestApplication;
  final int totalApplications;
  final DateTime? lastApplicationDate;

  StudentWithLatestApplication({
    required this.student,
    required this.latestApplication,
    required this.totalApplications,
    required this.lastApplicationDate,
  });

  // Get display properties
  String get studentName => student.fullName;
  String get studentInstitution => student.institution;
  String get studentCourse => student.courseOfStudy;
  String get studentLevel => "${student.level} Level";
  String? get studentImageUrl => student.imageUrl.isNotEmpty ? student.imageUrl : null;

  // Application properties (if exists)
  String? get internshipTitle => latestApplication?.internship.title ?? 'No Application';
  String? get internshipStatus => latestApplication?.applicationStatus ?? 'No Application';
  Color get statusColor => latestApplication?.statusColor ?? Colors.grey;
  IconData get statusIcon => latestApplication?.statusIcon ?? Icons.pending;

  DateTime? get startDate {
    final start = latestApplication?.durationDetails['startDate'];
    if (start is Timestamp) return start.toDate();
    if (start is String) return DateTime.tryParse(start);
    if (start is DateTime) return start;
    return null;
  }

  DateTime? get endDate {
    final end = latestApplication?.durationDetails['endDate'];
    if (end is Timestamp) return end.toDate();
    if (end is String) return DateTime.tryParse(end);
    if (end is DateTime) return end;
    return null;
  }

  String? get duration {
    final details = latestApplication?.durationDetails;
    final duration = details?['selectedDuration'] ?? details?['durationInDays'];
    if (duration is String) return duration;
    if (duration is int) return '$duration days';
    return null;
  }

  String get formattedLastDate {
    if (lastApplicationDate == null) return 'No applications';
    final now = DateTime.now();
    final difference = now.difference(lastApplicationDate!);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  bool get hasApplication => latestApplication != null;
  bool get hasMultipleApplications => totalApplications > 1;

  String get applicationsInfo {
    if (totalApplications == 0) return 'No applications';
    if (totalApplications == 1) return '1 application';
    return '$totalApplications applications';
  }

  Map<String, dynamic> toMap() {
    return {
      'student': student.toMap(),
      'latestApplication': latestApplication?.toMap(),
      'totalApplications': totalApplications,
      'lastApplicationDate': lastApplicationDate?.toIso8601String(),
    };
  }

  factory StudentWithLatestApplication.fromMap(Map<String, dynamic> map) {
    return StudentWithLatestApplication(
      student: Student.fromMap(map['student']),
      latestApplication: map['latestApplication'] != null
          ? StudentApplication.fromMap(
        map['latestApplication'] as Map<String, dynamic>,
        map['latestApplication']['internship']['id'] as String? ?? '',
        map['latestApplication']['id'] as String? ?? '',
      )
          : null,
      totalApplications: map['totalApplications'] as int? ?? 0,
      lastApplicationDate: map['lastApplicationDate'] != null
          ? DateTime.tryParse(map['lastApplicationDate'] as String)
          : null,
    );
  }

  // COPY WITH METHOD
  StudentWithLatestApplication copyWith({
    Student? student,
    StudentApplication? latestApplication,
    int? totalApplications,
    DateTime? lastApplicationDate,
  }) {
    return StudentWithLatestApplication(
      student: student ?? this.student,
      latestApplication: latestApplication ?? this.latestApplication,
      totalApplications: totalApplications ?? this.totalApplications,
      lastApplicationDate: lastApplicationDate ?? this.lastApplicationDate,
    );
  }


  @override
  String toString() {
    return 'StudentWithLatestApplication(student: $studentName, totalApplications: $totalApplications, lastApplication: $internshipTitle)';
  }
}