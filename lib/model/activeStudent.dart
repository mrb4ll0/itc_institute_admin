import 'package:cloud_firestore/cloud_firestore.dart';

import 'Assetments.dart';
import 'AttendanceRecord.dart';
import 'EmergencyContact.dart';
import 'MeetingRecord.dart';
import 'SupervisorInfo.dart';
import 'TrainingAdjustment.dart';
import 'TrainingDocument.dart';
import 'TrainingExtension.dart';
import 'TrainingLog.dart';
import 'TrainingMilestone.dart';
import 'TrainingTask.dart';
import 'WeeklyReport.dart';

class ActiveStudent {
  // Core student information (from Student model)
  String uid;
  String fullName;
  String email;
  String phoneNumber;
  String bio;
  String imageUrl;
  List<String> skills;
  String resumeUrl;
  List<String> certifications;
  String portfolioDescription;
  List<Map<String, dynamic>> pastInternships;
  List<String> idCards;
  List<String> itLetters;

  // Industrial Training Specific Fields
  String currentInternshipId; // Reference to the current IndustrialTraining
  String companyId; // Reference to the company

  // Training Status
  String trainingStatus; // 'pending', 'active', 'completed', 'terminated'
  DateTime? startDate;
  DateTime? expectedEndDate;
  DateTime? actualEndDate;

  // Progress Tracking
  double overallProgress; // 0.0 to 100.0
  List<TrainingMilestone> milestones;
  List<TrainingTask> tasks;

  // Assessment
  List<Assessment> assessments;
  String? finalGrade;
  String? supervisorReview;

  // Documentation
  List<TrainingDocument> documents;
  List<WeeklyReport> weeklyReports;
  List<AttendanceRecord> attendanceRecords;

  // Supervisors
  List<SupervisorInfo> supervisors;
  String? primarySupervisorId;

  // Logs and Communication
  List<TrainingLog> trainingLogs;
  List<MeetingRecord> meetings;

  // Extensions and Changes
  List<TrainingExtension> extensions;
  List<TrainingAdjustment> adjustments;

  // Emergency/Contact
  EmergencyContact emergencyContact;
  Map<String, dynamic> companyContactInfo;

  // Constructor
  ActiveStudent({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.bio = '',
    this.imageUrl = '',
    this.skills = const [],
    this.resumeUrl = '',
    this.certifications = const [],
    this.portfolioDescription = '',
    this.pastInternships = const [],
    this.idCards = const [],
    this.itLetters = const [],

    required this.currentInternshipId,
    required this.companyId,

    this.trainingStatus = 'pending',
    this.startDate,
    this.expectedEndDate,
    this.actualEndDate,

    this.overallProgress = 0.0,
    this.milestones = const [],
    this.tasks = const [],

    this.assessments = const [],
    this.finalGrade,
    this.supervisorReview,

    this.documents = const [],
    this.weeklyReports = const [],
    this.attendanceRecords = const [],

    this.supervisors = const [],
    this.primarySupervisorId,

    this.trainingLogs = const [],
    this.meetings = const [],

    this.extensions = const [],
    this.adjustments = const [],

    required this.emergencyContact,
    this.companyContactInfo = const {},
  });

  // Convert from Firestore document
  factory ActiveStudent.fromFirestore(Map<String, dynamic> data, String id) {
    return ActiveStudent(
      uid: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      bio: data['bio'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      resumeUrl: data['resumeUrl'] ?? '',
      certifications: List<String>.from(data['certifications'] ?? []),
      portfolioDescription: data['portfolioDescription'] ?? '',
      pastInternships: List<Map<String, dynamic>>.from(
        data['pastInternships'] ?? [],
      ),
      idCards: List<String>.from(data['idCards'] ?? []),
      itLetters: List<String>.from(data['itLetters'] ?? []),

      currentInternshipId: data['currentInternshipId'] ?? '',
      companyId: data['companyId'] ?? '',

      trainingStatus: data['trainingStatus'] ?? 'pending',
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      expectedEndDate: data['expectedEndDate'] != null
          ? (data['expectedEndDate'] as Timestamp).toDate()
          : null,
      actualEndDate: data['actualEndDate'] != null
          ? (data['actualEndDate'] as Timestamp).toDate()
          : null,

      overallProgress: (data['overallProgress'] as num?)?.toDouble() ?? 0.0,
      milestones: List<Map<String, dynamic>>.from(
        data['milestones'] ?? [],
      ).map((e) => TrainingMilestone.fromMap(e)).toList(),
      tasks: List<Map<String, dynamic>>.from(
        data['tasks'] ?? [],
      ).map((e) => TrainingTask.fromMap(e)).toList(),

      assessments: List<Map<String, dynamic>>.from(
        data['assessments'] ?? [],
      ).map((e) => Assessment.fromMap(e)).toList(),
      finalGrade: data['finalGrade'],
      supervisorReview: data['supervisorReview'],

      documents: List<Map<String, dynamic>>.from(
        data['documents'] ?? [],
      ).map((e) => TrainingDocument.fromMap(e)).toList(),
      weeklyReports: List<Map<String, dynamic>>.from(
        data['weeklyReports'] ?? [],
      ).map((e) => WeeklyReport.fromMap(e)).toList(),
      attendanceRecords: List<Map<String, dynamic>>.from(
        data['attendanceRecords'] ?? [],
      ).map((e) => AttendanceRecord.fromMap(e)).toList(),

      supervisors: List<Map<String, dynamic>>.from(
        data['supervisors'] ?? [],
      ).map((e) => SupervisorInfo.fromMap(e)).toList(),
      primarySupervisorId: data['primarySupervisorId'],

      trainingLogs: List<Map<String, dynamic>>.from(
        data['trainingLogs'] ?? [],
      ).map((e) => TrainingLog.fromMap(e)).toList(),
      meetings: List<Map<String, dynamic>>.from(
        data['meetings'] ?? [],
      ).map((e) => MeetingRecord.fromMap(e)).toList(),

      extensions: List<Map<String, dynamic>>.from(
        data['extensions'] ?? [],
      ).map((e) => TrainingExtension.fromMap(e)).toList(),
      adjustments: List<Map<String, dynamic>>.from(
        data['adjustments'] ?? [],
      ).map((e) => TrainingAdjustment.fromMap(e)).toList(),

      emergencyContact: EmergencyContact.fromMap(
        data['emergencyContact'] ?? {},
      ),
      companyContactInfo: Map<String, dynamic>.from(
        data['companyContactInfo'] ?? {},
      ),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      // Core student info
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'imageUrl': imageUrl,
      'skills': skills,
      'resumeUrl': resumeUrl,
      'certifications': certifications,
      'portfolioDescription': portfolioDescription,
      'pastInternships': pastInternships,
      'idCards': idCards,
      'itLetters': itLetters,

      // Training info
      'currentInternshipId': currentInternshipId,
      'companyId': companyId,

      'trainingStatus': trainingStatus,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'expectedEndDate': expectedEndDate != null
          ? Timestamp.fromDate(expectedEndDate!)
          : null,
      'actualEndDate': actualEndDate != null
          ? Timestamp.fromDate(actualEndDate!)
          : null,

      'overallProgress': overallProgress,
      'milestones': milestones.map((e) => e.toMap()).toList(),
      'tasks': tasks.map((e) => e.toMap()).toList(),

      'assessments': assessments.map((e) => e.toMap()).toList(),
      'finalGrade': finalGrade,
      'supervisorReview': supervisorReview,

      'documents': documents.map((e) => e.toMap()).toList(),
      'weeklyReports': weeklyReports.map((e) => e.toMap()).toList(),
      'attendanceRecords': attendanceRecords.map((e) => e.toMap()).toList(),

      'supervisors': supervisors.map((e) => e.toMap()).toList(),
      'primarySupervisorId': primarySupervisorId,

      'trainingLogs': trainingLogs.map((e) => e.toMap()).toList(),
      'meetings': meetings.map((e) => e.toMap()).toList(),

      'extensions': extensions.map((e) => e.toMap()).toList(),
      'adjustments': adjustments.map((e) => e.toMap()).toList(),

      'emergencyContact': emergencyContact.toMap(),
      'companyContactInfo': companyContactInfo,

      // Timestamps
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Helper methods
  bool get isActive => trainingStatus == 'active';
  bool get isCompleted => trainingStatus == 'completed';
  bool get isPending => trainingStatus == 'pending';

  Duration? get duration {
    if (startDate == null || expectedEndDate == null) return null;
    return expectedEndDate!.difference(startDate!);
  }

  Duration? get remainingTime {
    if (!isActive || expectedEndDate == null) return null;
    return expectedEndDate!.difference(DateTime.now());
  }

  bool get hasSupervisor => supervisors.isNotEmpty;

  SupervisorInfo? get primarySupervisor {
    if (primarySupervisorId == null) return null;
    return supervisors.firstWhere(
      (sup) => sup.id == primarySupervisorId,
      orElse: () => supervisors.firstOrNull ?? SupervisorInfo(),
    );
  }

  // Progress calculation
  double calculateProgress() {
    if (tasks.isEmpty) return 0.0;
    final completedTasks = tasks.where((task) => task.isCompleted).length;
    return (completedTasks / tasks.length) * 100.0;
  }

  // Add a new milestone
  ActiveStudent addMilestone(TrainingMilestone milestone) {
    return copyWith(milestones: [...milestones, milestone]);
  }

  // Add a new task
  ActiveStudent addTask(TrainingTask task) {
    return copyWith(tasks: [...tasks, task]);
  }

  // Add weekly report
  ActiveStudent addWeeklyReport(WeeklyReport report) {
    return copyWith(weeklyReports: [...weeklyReports, report]);
  }

  // Mark attendance
  ActiveStudent markAttendance(AttendanceRecord attendance) {
    return copyWith(attendanceRecords: [...attendanceRecords, attendance]);
  }

  // Add supervisor
  ActiveStudent addSupervisor(SupervisorInfo supervisor) {
    final newSupervisors = [...supervisors, supervisor];
    return copyWith(
      supervisors: newSupervisors,
      primarySupervisorId: primarySupervisorId ?? supervisor.id,
    );
  }

  // Copy with
  ActiveStudent copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? bio,
    String? imageUrl,
    List<String>? skills,
    String? resumeUrl,
    List<String>? certifications,
    String? portfolioDescription,
    List<Map<String, dynamic>>? pastInternships,
    List<String>? idCards,
    List<String>? itLetters,

    String? currentInternshipId,
    String? companyId,

    String? trainingStatus,
    DateTime? startDate,
    DateTime? expectedEndDate,
    DateTime? actualEndDate,

    double? overallProgress,
    List<TrainingMilestone>? milestones,
    List<TrainingTask>? tasks,

    List<Assessment>? assessments,
    String? finalGrade,
    String? supervisorReview,

    List<TrainingDocument>? documents,
    List<WeeklyReport>? weeklyReports,
    List<AttendanceRecord>? attendanceRecords,

    List<SupervisorInfo>? supervisors,
    String? primarySupervisorId,

    List<TrainingLog>? trainingLogs,
    List<MeetingRecord>? meetings,

    List<TrainingExtension>? extensions,
    List<TrainingAdjustment>? adjustments,

    EmergencyContact? emergencyContact,
    Map<String, dynamic>? companyContactInfo,
  }) {
    return ActiveStudent(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      imageUrl: imageUrl ?? this.imageUrl,
      skills: skills ?? this.skills,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      certifications: certifications ?? this.certifications,
      portfolioDescription: portfolioDescription ?? this.portfolioDescription,
      pastInternships: pastInternships ?? this.pastInternships,
      idCards: idCards ?? this.idCards,
      itLetters: itLetters ?? this.itLetters,

      currentInternshipId: currentInternshipId ?? this.currentInternshipId,
      companyId: companyId ?? this.companyId,

      trainingStatus: trainingStatus ?? this.trainingStatus,
      startDate: startDate ?? this.startDate,
      expectedEndDate: expectedEndDate ?? this.expectedEndDate,
      actualEndDate: actualEndDate ?? this.actualEndDate,

      overallProgress: overallProgress ?? this.overallProgress,
      milestones: milestones ?? this.milestones,
      tasks: tasks ?? this.tasks,

      assessments: assessments ?? this.assessments,
      finalGrade: finalGrade ?? this.finalGrade,
      supervisorReview: supervisorReview ?? this.supervisorReview,

      documents: documents ?? this.documents,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      attendanceRecords: attendanceRecords ?? this.attendanceRecords,

      supervisors: supervisors ?? this.supervisors,
      primarySupervisorId: primarySupervisorId ?? this.primarySupervisorId,

      trainingLogs: trainingLogs ?? this.trainingLogs,
      meetings: meetings ?? this.meetings,

      extensions: extensions ?? this.extensions,
      adjustments: adjustments ?? this.adjustments,

      emergencyContact: emergencyContact ?? this.emergencyContact,
      companyContactInfo: companyContactInfo ?? this.companyContactInfo,
    );
  }
}

// Supporting Classes
