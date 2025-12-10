import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/model/activeStudent.dart' as models;

import '../../model/Assetments.dart';
import '../../model/AttendanceRecord.dart';
import '../../model/MeetingRecord.dart';
import '../../model/SupervisorInfo.dart';
import '../../model/TrainingAdjustment.dart';
import '../../model/TrainingDocument.dart';
import '../../model/TrainingExtension.dart';
import '../../model/TrainingLog.dart';
import '../../model/TrainingTask.dart';
import '../../model/WeeklyReport.dart';

class ActiveTrainingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference _companyTraineesRef(String companyId) {
    return _firestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('currentTrainees');
  }

  // Get all active trainees for a company
  Stream<List<models.ActiveStudent>> streamCompanyTrainees(String companyId) {
    return _companyTraineesRef(companyId).snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => models.ActiveStudent.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList(),
    );
  }

  // Get specific trainee
  Future<models.ActiveStudent?> getTrainee(
    String companyId,
    String studentId,
  ) async {
    try {
      final doc = await _companyTraineesRef(companyId).doc(studentId).get();
      if (doc.exists) {
        return models.ActiveStudent.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting trainee: $e');
      return null;
    }
  }

  // Stream specific trainee
  Stream<models.ActiveStudent?> streamTrainee(
    String companyId,
    String studentId,
  ) {
    return _companyTraineesRef(companyId).doc(studentId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return models.ActiveStudent.fromFirestore(
          snapshot.data() as Map<String, dynamic>,
          snapshot.id,
        );
      }
      return null;
    });
  }

  // Add/Update trainee
  Future<bool> saveTrainee(
    String companyId,
    models.ActiveStudent trainee,
  ) async {
    try {
      await _companyTraineesRef(
        companyId,
      ).doc(trainee.uid).set(trainee.toMap());
      return true;
    } catch (e) {
      print('Error saving trainee: $e');
      return false;
    }
  }

  // Remove trainee
  Future<bool> removeTrainee(String companyId, String studentId) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).delete();
      return true;
    } catch (e) {
      print('Error removing trainee: $e');
      return false;
    }
  }

  // MARK: Progress Management

  // Update overall progress
  Future<bool> updateProgress(
    String companyId,
    String studentId,
    double progress,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'overallProgress': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating progress: $e');
      return false;
    }
  }

  // Update training status
  Future<bool> updateTrainingStatus(
    String companyId,
    String studentId,
    String status, { // 'pending', 'active', 'completed', 'terminated'
    DateTime? actualEndDate,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'trainingStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (actualEndDate != null) {
        updateData['actualEndDate'] = Timestamp.fromDate(actualEndDate);
      }

      await _companyTraineesRef(companyId).doc(studentId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating training status: $e');
      return false;
    }
  }

  // MARK: Task Management

  // Add task
  Future<bool> addTask(
    String companyId,
    String studentId,
    TrainingTask task,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'tasks': FieldValue.arrayUnion([task.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding task: $e');
      return false;
    }
  }

  // Update task completion
  Future<bool> updateTaskCompletion(
    String companyId,
    String studentId,
    String taskId,
    bool isCompleted, {
    String? notes,
    DateTime? completedDate,
  }) async {
    try {
      final trainee = await getTrainee(companyId, studentId);
      if (trainee == null) return false;

      final updatedTasks = trainee.tasks.map((task) {
        if (task.id == taskId) {
          return TrainingTask(
            id: task.id,
            title: task.title,
            description: task.description,
            deadline: task.deadline,
            isCompleted: isCompleted,
            completedDate:
                completedDate ?? (isCompleted ? DateTime.now() : null),
            notes: notes ?? task.notes,
            priority: task.priority,
          );
        }
        return task;
      }).toList();

      // Recalculate progress
      final newProgress = trainee
          .copyWith(tasks: updatedTasks)
          .calculateProgress();

      await _companyTraineesRef(companyId).doc(studentId).update({
        'tasks': updatedTasks.map((t) => t.toMap()).toList(),
        'overallProgress': newProgress,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }

  // MARK: Attendance Management

  // Mark attendance for a day
  Future<bool> markAttendance(
    String companyId,
    String studentId,
    AttendanceRecord attendance,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'attendanceRecords': FieldValue.arrayUnion([attendance.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  // Update check-in/out
  Future<bool> updateAttendanceCheck(
    String companyId,
    String studentId,
    DateTime date, {
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) async {
    try {
      final trainee = await getTrainee(companyId, studentId);
      if (trainee == null) return false;

      // Find existing attendance record for the date
      final dateOnly = DateTime(date.year, date.month, date.day);
      final existingRecord = trainee.attendanceRecords.firstWhere(
        (record) =>
            DateTime(record.date.year, record.date.month, record.date.day) ==
            dateOnly,
        orElse: () => AttendanceRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: date,
          isPresent: checkInTime != null || checkOutTime != null,
        ),
      );

      final updatedRecord = AttendanceRecord(
        id: existingRecord.id,
        date: existingRecord.date,
        checkInTime: checkInTime ?? existingRecord.checkInTime,
        checkOutTime: checkOutTime ?? existingRecord.checkOutTime,
        notes: existingRecord.notes,
        isPresent: true,
      );

      // Remove old record if exists
      final updatedRecords =
          List<AttendanceRecord>.from(trainee.attendanceRecords)
            ..removeWhere((record) => record.id == existingRecord.id)
            ..add(updatedRecord);

      await _companyTraineesRef(companyId).doc(studentId).update({
        'attendanceRecords': updatedRecords.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating attendance: $e');
      return false;
    }
  }

  // Get attendance summary
  Future<Map<String, dynamic>> getAttendanceSummary(
    String companyId,
    String studentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final trainee = await getTrainee(companyId, studentId);
    if (trainee == null) return {};

    final records = trainee.attendanceRecords.where(
      (record) =>
          record.date.isAfter(startDate) && record.date.isBefore(endDate),
    );

    final totalDays = records.length;
    final presentDays = records.where((r) => r.isPresent).length;
    final absentDays = totalDays - presentDays;
    final lateDays = records
        .where(
          (r) =>
              r.checkInTime != null &&
              r.checkInTime!.hour > 9, // Assuming 9 AM is start time
        )
        .length;

    return {
      'totalDays': totalDays,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'lateDays': lateDays,
      'attendanceRate': totalDays > 0 ? (presentDays / totalDays) * 100 : 0,
      'records': records.map((r) => r.toMap()).toList(),
    };
  }

  // MARK: Assessment & Grading

  // Add assessment
  Future<bool> addAssessment(
    String companyId,
    String studentId,
    Assessment assessment,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'assessments': FieldValue.arrayUnion([assessment.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding assessment: $e');
      return false;
    }
  }

  // Calculate final grade
  Future<bool> calculateAndSetFinalGrade(
    String companyId,
    String studentId,
  ) async {
    try {
      final trainee = await getTrainee(companyId, studentId);
      if (trainee == null) return false;

      if (trainee.assessments.isEmpty) {
        // No assessments yet
        await _companyTraineesRef(companyId).doc(studentId).update({
          'finalGrade': 'N/A',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // Calculate weighted average
      double totalWeightedScore = 0;
      double totalWeight = 0;

      for (final assessment in trainee.assessments) {
        double weight = _getAssessmentWeight(assessment.type);
        totalWeightedScore +=
            (assessment.score / assessment.maxScore) * 100 * weight;
        totalWeight += weight;
      }

      final averageScore = totalWeight > 0
          ? totalWeightedScore / totalWeight
          : 0.0;
      final grade = _scoreToGrade(averageScore);

      await _companyTraineesRef(companyId).doc(studentId).update({
        'finalGrade': grade,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error calculating final grade: $e');
      return false;
    }
  }

  // Helper: Get assessment weight based on type
  double _getAssessmentWeight(String type) {
    switch (type.toLowerCase()) {
      case 'final':
        return 0.4;
      case 'midterm':
        return 0.3;
      case 'project':
        return 0.2;
      case 'weekly':
        return 0.1;
      default:
        return 0.1;
    }
  }

  // Helper: Convert score to letter grade
  String _scoreToGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  // Add supervisor review
  Future<bool> addSupervisorReview(
    String companyId,
    String studentId,
    String review,
    String supervisorId,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'supervisorReview': review,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to training logs
      final log = TrainingLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        category: 'assessment',
        description: 'Supervisor review added',
        notes: 'Review by supervisor ID: $supervisorId',
        loggedBy: supervisorId,
      );

      await _companyTraineesRef(companyId).doc(studentId).update({
        'trainingLogs': FieldValue.arrayUnion([log.toMap()]),
      });

      return true;
    } catch (e) {
      print('Error adding supervisor review: $e');
      return false;
    }
  }

  // MARK: Weekly Reports

  // Submit weekly report
  Future<bool> submitWeeklyReport(
    String companyId,
    String studentId,
    WeeklyReport report,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'weeklyReports': FieldValue.arrayUnion([report.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error submitting weekly report: $e');
      return false;
    }
  }

  // Add supervisor feedback to weekly report
  Future<bool> addWeeklyReportFeedback(
    String companyId,
    String studentId,
    String reportId,
    String feedback,
    String supervisorId,
  ) async {
    try {
      final trainee = await getTrainee(companyId, studentId);
      if (trainee == null) return false;

      final updatedReports = trainee.weeklyReports.map((report) {
        if (report.id == reportId) {
          return WeeklyReport(
            id: report.id,
            weekNumber: report.weekNumber,
            startDate: report.startDate,
            endDate: report.endDate,
            tasksCompleted: report.tasksCompleted,
            challenges: report.challenges,
            learnings: report.learnings,
            plansForNextWeek: report.plansForNextWeek,
            submittedDate: report.submittedDate,
            supervisorFeedback: feedback,
            feedbackDate: DateTime.now(),
          );
        }
        return report;
      }).toList();

      await _companyTraineesRef(companyId).doc(studentId).update({
        'weeklyReports': updatedReports.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error adding weekly report feedback: $e');
      return false;
    }
  }

  // MARK: Supervisor Management

  // Add supervisor
  Future<bool> addSupervisor(
    String companyId,
    String studentId,
    SupervisorInfo supervisor, {
    bool setAsPrimary = false,
  }) async {
    try {
      final updates = <String, dynamic>{
        'supervisors': FieldValue.arrayUnion([supervisor.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (setAsPrimary) {
        updates['primarySupervisorId'] = supervisor.id;
      }

      await _companyTraineesRef(companyId).doc(studentId).update(updates);
      return true;
    } catch (e) {
      print('Error adding supervisor: $e');
      return false;
    }
  }

  // Set primary supervisor
  Future<bool> setPrimarySupervisor(
    String companyId,
    String studentId,
    String supervisorId,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'primarySupervisorId': supervisorId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error setting primary supervisor: $e');
      return false;
    }
  }

  // MARK: Document Management

  // Upload document
  Future<bool> uploadDocument(
    String companyId,
    String studentId,
    TrainingDocument document,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'documents': FieldValue.arrayUnion([document.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error uploading document: $e');
      return false;
    }
  }

  // MARK: Meeting Management

  // Schedule meeting
  Future<bool> scheduleMeeting(
    String companyId,
    String studentId,
    MeetingRecord meeting,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'meetings': FieldValue.arrayUnion([meeting.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error scheduling meeting: $e');
      return false;
    }
  }

  // Update meeting completion
  Future<bool> updateMeetingCompletion(
    String companyId,
    String studentId,
    String meetingId,
    bool isCompleted, {
    String? minutes,
    DateTime? actualTime,
  }) async {
    try {
      final trainee = await getTrainee(companyId, studentId);
      if (trainee == null) return false;

      final updatedMeetings = trainee.meetings.map((meeting) {
        if (meeting.id == meetingId) {
          return MeetingRecord(
            id: meeting.id,
            title: meeting.title,
            description: meeting.description,
            scheduledTime: meeting.scheduledTime,
            actualTime: actualTime ?? meeting.actualTime,
            location: meeting.location,
            meetingLink: meeting.meetingLink,
            attendees: meeting.attendees,
            agenda: meeting.agenda,
            minutes: minutes ?? meeting.minutes,
            isCompleted: isCompleted,
          );
        }
        return meeting;
      }).toList();

      await _companyTraineesRef(companyId).doc(studentId).update({
        'meetings': updatedMeetings.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating meeting: $e');
      return false;
    }
  }

  // MARK: Training Extensions & Adjustments

  // Request extension
  Future<bool> requestExtension(
    String companyId,
    String studentId,
    TrainingExtension extension,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'extensions': FieldValue.arrayUnion([extension.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error requesting extension: $e');
      return false;
    }
  }

  // Approve/reject extension
  Future<bool> updateExtensionStatus(
    String companyId,
    String studentId,
    String extensionId,
    String status,
    String approvedBy, {
    String? comments,
  }) async {
    try {
      final trainee = await getTrainee(companyId, studentId);
      if (trainee == null) return false;

      final updatedExtensions = trainee.extensions.map((extension) {
        if (extension.id == extensionId) {
          return TrainingExtension(
            id: extension.id,
            reason: extension.reason,
            originalEndDate: extension.originalEndDate,
            newEndDate: extension.newEndDate,
            requestDate: extension.requestDate,
            approvalDate: DateTime.now(),
            status: status,
            approvedBy: approvedBy,
            comments: comments ?? extension.comments,
          );

          // If approved, update expected end date
          if (status == 'approved') {
            _updateExpectedEndDate(companyId, studentId, extension.newEndDate);
          }
        }
        return extension;
      }).toList();

      await _companyTraineesRef(companyId).doc(studentId).update({
        'extensions': updatedExtensions.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating extension status: $e');
      return false;
    }
  }

  // Helper: Update expected end date
  Future<void> _updateExpectedEndDate(
    String companyId,
    String studentId,
    DateTime newEndDate,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'expectedEndDate': Timestamp.fromDate(newEndDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating expected end date: $e');
    }
  }

  // Request adjustment
  Future<bool> requestAdjustment(
    String companyId,
    String studentId,
    TrainingAdjustment adjustment,
  ) async {
    try {
      await _companyTraineesRef(companyId).doc(studentId).update({
        'adjustments': FieldValue.arrayUnion([adjustment.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error requesting adjustment: $e');
      return false;
    }
  }

  // MARK: Query Methods

  // Get trainees by status
  Stream<List<models.ActiveStudent>> streamTraineesByStatus(
    String companyId,
    String status,
  ) {
    return _companyTraineesRef(companyId)
        .where('trainingStatus', isEqualTo: status)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => models.ActiveStudent.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // Get trainees ending soon (within X days)
  Future<List<models.ActiveStudent>> getTraineesEndingSoon(
    String companyId,
    int days,
  ) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.add(Duration(days: days));

      final snapshot = await _companyTraineesRef(
        companyId,
      ).where('trainingStatus', isEqualTo: 'active').get();

      return snapshot.docs
          .map(
            (doc) => models.ActiveStudent.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .where(
            (trainee) =>
                trainee.expectedEndDate != null &&
                trainee.expectedEndDate!.isBefore(cutoffDate),
          )
          .toList();
    } catch (e) {
      print('Error getting trainees ending soon: $e');
      return [];
    }
  }

  // Get trainees with low progress (< X%)
  Future<List<models.ActiveStudent>> getTraineesWithLowProgress(
    String companyId,
    double threshold,
  ) async {
    try {
      final snapshot = await _companyTraineesRef(
        companyId,
      ).where('trainingStatus', isEqualTo: 'active').get();

      return snapshot.docs
          .map(
            (doc) => models.ActiveStudent.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .where((trainee) => trainee.overallProgress < threshold)
          .toList();
    } catch (e) {
      print('Error getting trainees with low progress: $e');
      return [];
    }
  }

  // Get trainees by supervisor
  Stream<List<models.ActiveStudent>> streamTraineesBySupervisor(
    String companyId,
    String supervisorId,
  ) {
    return _companyTraineesRef(companyId)
        .where('supervisors', arrayContains: supervisorId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => models.ActiveStudent.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // MARK: Batch Operations

  // Bulk update attendance
  Future<bool> bulkUpdateAttendance(
    String companyId,
    List<String> studentIds,
    DateTime date,
    bool isPresent,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final studentId in studentIds) {
        final docRef = _companyTraineesRef(companyId).doc(studentId);

        // Create attendance record
        final attendance = AttendanceRecord(
          id: '${date.millisecondsSinceEpoch}_$studentId',
          date: date,
          isPresent: isPresent,
        );

        batch.update(docRef, {
          'attendanceRecords': FieldValue.arrayUnion([attendance.toMap()]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error in bulk attendance update: $e');
      return false;
    }
  }

  // Bulk update progress
  Future<bool> bulkUpdateProgress(
    String companyId,
    List<String> studentIds,
    double progress,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final studentId in studentIds) {
        final docRef = _companyTraineesRef(companyId).doc(studentId);
        batch.update(docRef, {
          'overallProgress': progress,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error in bulk progress update: $e');
      return false;
    }
  }

  // MARK: Analytics & Reports

  // Get training statistics for company
  Future<Map<String, dynamic>> getTrainingStatistics(String companyId) async {
    try {
      final snapshot = await _companyTraineesRef(companyId).get();
      final trainees = snapshot.docs
          .map(
            (doc) => models.ActiveStudent.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();

      final activeTrainees = trainees.where((t) => t.isActive).length;
      final completedTrainees = trainees.where((t) => t.isCompleted).length;
      final pendingTrainees = trainees.where((t) => t.isPending).length;

      // Calculate average progress
      final activeTraineesList = trainees.where((t) => t.isActive).toList();
      final averageProgress = activeTraineesList.isNotEmpty
          ? activeTraineesList
                    .map((t) => t.overallProgress)
                    .reduce((a, b) => a + b) /
                activeTraineesList.length
          : 0;

      // Calculate completion rate
      final totalTrainees = trainees.length;
      final completionRate = totalTrainees > 0
          ? (completedTrainees / totalTrainees) * 100
          : 0;

      return {
        'totalTrainees': totalTrainees,
        'activeTrainees': activeTrainees,
        'completedTrainees': completedTrainees,
        'pendingTrainees': pendingTrainees,
        'averageProgress': averageProgress,
        'completionRate': completionRate,
        'traineesByStatus': {
          'active': activeTrainees,
          'completed': completedTrainees,
          'pending': pendingTrainees,
        },
      };
    } catch (e) {
      print('Error getting training statistics: $e');
      return {};
    }
  }

  // Generate progress report for trainee
  Future<Map<String, dynamic>> generateProgressReport(
    String companyId,
    String studentId,
  ) async {
    final trainee = await getTrainee(companyId, studentId);
    if (trainee == null) return {};

    // Calculate task completion stats
    final totalTasks = trainee.tasks.length;
    final completedTasks = trainee.tasks.where((t) => t.isCompleted).length;
    final pendingTasks = totalTasks - completedTasks;

    // Calculate milestone completion
    final totalMilestones = trainee.milestones.length;
    final completedMilestones = trainee.milestones
        .where((m) => m.isCompleted)
        .length;

    // Calculate attendance for current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final attendanceSummary = await getAttendanceSummary(
      companyId,
      studentId,
      startOfMonth,
      now,
    );

    // Get latest weekly report
    final latestReport = trainee.weeklyReports.isNotEmpty
        ? trainee.weeklyReports.last
        : null;

    // Get upcoming deadlines (tasks due in next 7 days)
    final upcomingDeadlines = trainee.tasks
        .where(
          (task) =>
              !task.isCompleted &&
              task.deadline.isAfter(now) &&
              task.deadline.isBefore(now.add(const Duration(days: 7))),
        )
        .toList();

    return {
      'traineeInfo': {
        'name': trainee.fullName,
        'email': trainee.email,
        'status': trainee.trainingStatus,
        'progress': trainee.overallProgress,
      },
      'tasks': {
        'total': totalTasks,
        'completed': completedTasks,
        'pending': pendingTasks,
        'completionRate': totalTasks > 0
            ? (completedTasks / totalTasks) * 100
            : 0,
      },
      'milestones': {
        'total': totalMilestones,
        'completed': completedMilestones,
        'pending': totalMilestones - completedMilestones,
      },
      'attendance': attendanceSummary,
      'latestWeeklyReport': latestReport?.toMap(),
      'assessments': {
        'count': trainee.assessments.length,
        'averageScore': trainee.assessments.isNotEmpty
            ? trainee.assessments.map((a) => a.score).reduce((a, b) => a + b) /
                  trainee.assessments.length
            : 0,
      },
      'upcomingDeadlines': upcomingDeadlines.map((t) => t.toMap()).toList(),
      'supervisorFeedback': trainee.supervisorReview,
      'finalGrade': trainee.finalGrade,
      'generatedAt': DateTime.now(),
    };
  }

  // In your ActiveTrainingService class
  Future<List<models.ActiveStudent>> getActiveTrainees(String companyId) async {
    try {
      final snapshot = await _companyTraineesRef(
        companyId,
      ).where('trainingStatus', isEqualTo: 'active').get();

      return snapshot.docs
          .map(
            (doc) => models.ActiveStudent.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting active trainees: $e');
      return [];
    }
  }

  // In ActiveTrainingService class
  Future<int> getActiveTraineesCount(String companyId) async {
    try {
      final query = _companyTraineesRef(
        companyId,
      ).where('trainingStatus', isEqualTo: 'active');

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting active trainees count: $e');
      return 0;
    }
  }
}
