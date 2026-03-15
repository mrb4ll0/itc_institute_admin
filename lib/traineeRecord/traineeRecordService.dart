import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


import '../../model/company.dart';
import '../../model/internship_model.dart';
import '../../model/studentApplication.dart';
import '../itc_logic/firebase/company_cloud.dart';
import '../itc_logic/service/tranineeService.dart';
import '../model/traineeRecord.dart';

// ==================== TRAINEE RECORD MODEL ====================

class ITTraineeRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final String studentDepartment;
  final String studentLevel;
  final String studentMatricNo;

  final String companyId;
  final String companyName;
  final String companyEmail;
  final String companyPhone;
  final String companyAddress;

  final String internshipId;
  final String internshipTitle;
  final String internshipDescription;

  final String applicationId;
  final String applicationStatus;
  final DateTime applicationDate;
  final Map<String, dynamic> durationDetails;

  final DateTime startDate;
  final DateTime? endDate;
  final String status; // active, completed, terminated

  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  ITTraineeRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentPhone,
    required this.studentDepartment,
    required this.studentLevel,
    required this.studentMatricNo,
    required this.companyId,
    required this.companyName,
    required this.companyEmail,
    required this.companyPhone,
    required this.companyAddress,
    required this.internshipId,
    required this.internshipTitle,
    required this.internshipDescription,
    required this.applicationId,
    required this.applicationStatus,
    required this.applicationDate,
    required this.durationDetails,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  // Create a copy with updated fields
  ITTraineeRecord copyWith({
    String? status,
    DateTime? endDate,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
  }) {
    return ITTraineeRecord(
      id: id,
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      studentPhone: studentPhone,
      studentDepartment: studentDepartment,
      studentLevel: studentLevel,
      studentMatricNo: studentMatricNo,
      companyId: companyId,
      companyName: companyName,
      companyEmail: companyEmail,
      companyPhone: companyPhone,
      companyAddress: companyAddress,
      internshipId: internshipId,
      internshipTitle: internshipTitle,
      internshipDescription: internshipDescription,
      applicationId: applicationId,
      applicationStatus: applicationStatus,
      applicationDate: applicationDate,
      durationDetails: durationDetails,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert from Firestore document
  factory ITTraineeRecord.fromFirestore(
      DocumentSnapshot doc,
      ) {
    final data = doc.data() as Map<String, dynamic>;
    return ITTraineeRecord.fromMap(doc.id, data);
  }

  // Convert from Map
  factory ITTraineeRecord.fromMap(String id, Map<String, dynamic> map) {
    return ITTraineeRecord(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentEmail: map['studentEmail'] ?? '',
      studentPhone: map['studentPhone'] ?? '',
      studentDepartment: map['studentDepartment'] ?? '',
      studentLevel: map['studentLevel'] ?? '',
      studentMatricNo: map['studentMatricNo'] ?? '',
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      companyEmail: map['companyEmail'] ?? '',
      companyPhone: map['companyPhone'] ?? '',
      companyAddress: map['companyAddress'] ?? '',
      internshipId: map['internshipId'] ?? '',
      internshipTitle: map['internshipTitle'] ?? '',
      internshipDescription: map['internshipDescription'] ?? '',
      applicationId: map['applicationId'] ?? '',
      applicationStatus: map['applicationStatus'] ?? '',
      applicationDate: (map['applicationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationDetails: map['durationDetails'] as Map<String, dynamic>? ?? {},
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      status: map['status'] ?? 'active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentPhone': studentPhone,
      'studentDepartment': studentDepartment,
      'studentLevel': studentLevel,
      'studentMatricNo': studentMatricNo,
      'companyId': companyId,
      'companyName': companyName,
      'companyEmail': companyEmail,
      'companyPhone': companyPhone,
      'companyAddress': companyAddress,
      'internshipId': internshipId,
      'internshipTitle': internshipTitle,
      'internshipDescription': internshipDescription,
      'applicationId': applicationId,
      'applicationStatus': applicationStatus,
      'applicationDate': Timestamp.fromDate(applicationDate),
      'durationDetails': durationDetails,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  // Convert to Map for Firestore with server timestamps
  Map<String, dynamic> toFirestoreMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentPhone': studentPhone,
      'studentDepartment': studentDepartment,
      'studentLevel': studentLevel,
      'studentMatricNo': studentMatricNo,
      'companyId': companyId,
      'companyName': companyName,
      'companyEmail': companyEmail,
      'companyPhone': companyPhone,
      'companyAddress': companyAddress,
      'internshipId': internshipId,
      'internshipTitle': internshipTitle,
      'internshipDescription': internshipDescription,
      'applicationId': applicationId,
      'applicationStatus': applicationStatus,
      'applicationDate': Timestamp.fromDate(applicationDate),
      'durationDetails': durationDetails,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    };
  }

  // Helper getters
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isTerminated => status == 'terminated';

  String get formattedDuration {
    if (endDate == null) return 'Ongoing';
    final duration = endDate!.difference(startDate);
    final days = duration.inDays;
    return '$days days';
  }


  static TraineeStatus _parseTraineeStatus(dynamic value) {
    debugPrint("status in parse is $value");
    if (value == null) return TraineeStatus.pending;
    final str = value.toString().toLowerCase();
    switch (str) {
      case 'active': return TraineeStatus.active;
      case 'onhold': return TraineeStatus.onHold;
      case 'accepted': return TraineeStatus.accepted;
      case 'completed': return TraineeStatus.completed;
      case 'terminated': return TraineeStatus.terminated;
      case 'withdrawn': return TraineeStatus.withdrawn;
      case 'rejected': return TraineeStatus.rejected;
      default: return TraineeStatus.pending;
    }
  }

  TraineeStatus get traineeStatus=> _parseTraineeStatus(this.status);

}

// ==================== TRAINEE RECORD SERVICE ====================

class TraineeRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
   final bool isAuthority;
   TraineeRecordService({required bool this.isAuthority});

  // Collection names
  static const String traineesCollection = 'traineerecords';
  static const String companiesCollection = 'companies';
  static const String usersCollection = 'users';

  /// Creates a trainee record when a student accepts an application
  /// Returns the created TraineeRecord or throws an error if creation fails
  Future<ITTraineeRecord> createTraineeRecord({
    required String companyId,
    required String internshipId,
    required String studentId,
    required StudentApplication application,
    required IndustrialTraining internship,
    required Company company,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Check if trainee record already exists for this student
      final existingRecord = await getTraineeRecord(studentId);
      if (existingRecord != null) {
        debugPrint('Trainee record already exists for student: $studentId');
        return existingRecord;
      }

      // Create the document ID as applicationId_studentId
      final applicationId = application.id;
      final traineeRecordId = '${applicationId}_$studentId';

      // Reference to the trainee record
      final traineeRecordRef = _firestore
          .collection(traineesCollection)
          .doc(traineeRecordId);

      // Create TraineeRecord object
      final now = DateTime.now();
      final traineeRecord = ITTraineeRecord(
        id: traineeRecordId,
        studentId: studentId,
        studentName: application.student.fullName,
        studentEmail: application.student.email,
        studentPhone: application.student.phoneNumber,
        studentDepartment: application.student.department,
        studentLevel: application.student.level,
        studentMatricNo: application.student.matricNumber,
        companyId: companyId,
        companyName: company.name,
        companyEmail: company.email,
        companyPhone: company.phoneNumber,
        companyAddress: '${company.localGovernment}, ${company.state}',
        internshipId: internshipId,
        internshipTitle: internship.title,
        internshipDescription: internship.description,
        applicationId: applicationId,
        applicationStatus: application.applicationStatus,
        applicationDate: application.applicationDate,
        durationDetails: application.durationDetails,
        startDate: startDate ?? now,
        endDate: endDate,
        status: 'active',
        createdAt: now,
        updatedAt: now,
        metadata: {
          'hasStarted': false,
          'hasCompleted': false,
          'progress': 0,
          'lastUpdated': now.toIso8601String(),
        },
      );

      // Save to Firestore
      await traineeRecordRef.set(traineeRecord.toFirestoreMap());

      // Update student's document with trainee record reference
      await _updateStudentWithTraineeRecord(studentId, traineeRecordId);

      // Update the application status to 'confirmed'
      await Company_Cloud(FirebaseAuth.instance.currentUser?.uid??"").updateApplicationStatus(
        companyId: companyId,
        internshipId: internshipId,
        studentId: studentId,
        status: 'confirmed',
        application: application,
        isAuthority: isAuthority
      );

      debugPrint('Trainee record created successfully: $traineeRecordId');
      return traineeRecord;

    } catch (e, stackTrace) {
      debugPrint('Error creating trainee record: $e');
      debugPrint('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Get a trainee record for a student
  Future<ITTraineeRecord?> getTraineeRecord(String studentId) async {
    try {
      // First check if student document has direct reference
      final studentDoc = await _firestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(studentId)
          .get();

      if (studentDoc.exists) {
        final studentData = studentDoc.data();
        debugPrint('Student data: $studentData');
        final traineeRecordId = studentData?['traineeRecordId'];
        debugPrint("traineeRecordId");

        if (traineeRecordId != null) {
          // Direct access using stored ID
          final traineeDoc = await _firestore
              .collection(traineesCollection)
              .doc(traineeRecordId)
              .get();

          if (traineeDoc.exists) {
            return ITTraineeRecord.fromFirestore(traineeDoc);
          }
        }
      }

      // Fallback: Query by document ID pattern
      final searchPattern = '_$studentId';
      final traineesRef = _firestore.collection(traineesCollection);

      final querySnapshot = await traineesRef
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '\u0000$searchPattern')
          .where(FieldPath.documentId, isLessThan: '\uf8ff$searchPattern' + '\uf8ff')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      // Verify exact match
      final doc = querySnapshot.docs.first;
      if (doc.id.endsWith(searchPattern)) {
        return ITTraineeRecord.fromFirestore(doc);
      }

      return null;

    } catch (e) {
      debugPrint('Error getting trainee record: $e');
      return null;
    }
  }

  /// Stream trainee record for a student
  Stream<ITTraineeRecord?> streamTraineeRecord(String studentId) {
    try {
      // First try to get by student document reference
      return _firestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(studentId)
          .snapshots()
          .asyncMap((studentDoc) async {
        if (!studentDoc.exists) return null;

        final traineeRecordId = studentDoc.data()?['traineeRecordId'];
        if (traineeRecordId == null) return null;

        final traineeDoc = await _firestore
            .collection(traineesCollection)
            .doc(traineeRecordId)
            .get();

        return traineeDoc.exists
            ? ITTraineeRecord.fromFirestore(traineeDoc)
            : null;
      });
    } catch (e) {
      debugPrint('Error streaming trainee record: $e');
      return Stream.value(null);
    }
  }

  /// Get all trainee records for a company
  Future<List<ITTraineeRecord>> getCompanyTraineeRecords(String companyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(traineesCollection)
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ITTraineeRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting company trainee records: $e');
      return [];
    }
  }

  /// Check if student has a trainee record
  Future<bool> hasTraineeRecord(String studentId, String applicationId) async {
    try {
      final traineeRecordId = '${applicationId}_$studentId';
      final docSnapshot = await _firestore
          .collection(traineesCollection)
          .doc(traineeRecordId)
          .get();

      return docSnapshot.exists;
    } catch (e) {
      debugPrint('Error checking trainee record: $e');
      return false;
    }
  }

  /// Update trainee record status
  Future<void> updateTraineeRecordStatus({
    required String studentId,
    required String applicationId,
    required String newStatus,
    DateTime? endDate,
  }) async {
    try {
      final traineeRecordId = '${applicationId}_$studentId';
      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (endDate != null) {
        updates['endDate'] = Timestamp.fromDate(endDate);
      }

      if (newStatus == 'completed') {
        updates['metadata.hasCompleted'] = true;
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection(traineesCollection)
          .doc(traineeRecordId)
          .update(updates);

      // Update student record if completed
      if (newStatus == 'completed') {
        await _firestore
            .collection(usersCollection)
            .doc('students')
            .collection('students')
            .doc(studentId)
            .update({
          'hasActiveTraineeRecord': false,
          'lastTraineeRecordId': traineeRecordId,
        });
      }
    } catch (e) {
      debugPrint('Error updating trainee record status: $e');
      rethrow;
    }
  }

  /// Update complete trainee record
  Future<void> updateTraineeRecord(TraineeRecord trainee) async {
    try {
      // Create the trainee record ID (using your existing pattern)
      final traineeRecordId = '${trainee.applicationId}_${trainee.studentId}';

      // Build the updates map
      final updates = <String, dynamic>{
        'studentId': trainee.studentId,
        'studentName': trainee.studentName,
        'companyId': trainee.companyId,
        'status': trainee.status.toString().split('.').last, // Convert enum to string (e.g., "TraineeStatus.active" -> "active")
        'statusDescription': trainee.statusDescription,
        'needsStatusUpdate': trainee.needsStatusUpdate,
        'department': trainee.department,
        'role': trainee.role,
        'progress': trainee.progress,
        'imageUrl': trainee.imageUrl,
        'supervisorIds': trainee.supervisorIds,
        'notes': trainee.notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add dates if they exist
      if (trainee.startDate != null) {
        updates['startDate'] = Timestamp.fromDate(trainee.startDate!);
      }
      if (trainee.endDate != null) {
        updates['endDate'] = Timestamp.fromDate(trainee.endDate!);
      }
      if (trainee.actualStartDate != null) {
        updates['actualStartDate'] = Timestamp.fromDate(trainee.actualStartDate!);
      }
      if (trainee.actualEndDate != null) {
        updates['actualEndDate'] = Timestamp.fromDate(trainee.actualEndDate!);
      }
      if (trainee.durationInDays != null) {
        updates['durationInDays'] = trainee.durationInDays;
      }

      // Add metadata based on status
      final statusString = trainee.status.toString().split('.').last;
      updates['metadata'] = {
        'hasActiveTraining': ['active', 'onHold'].contains(statusString),
        'hasCompleted': statusString == 'completed',
        'hasWithdrawn': statusString == 'withdrawn',
        'hasTerminated': statusString == 'terminated',
        'isAccepted': statusString == 'accepted',
        'isPending': statusString == 'pending',
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      };

      // Update the trainee record in Firestore
      await _firestore
          .collection(traineesCollection) // Use your existing collection name
          .doc(traineeRecordId)
          .update(updates);

      debugPrint('Trainee record updated successfully: ${trainee.studentName}');

    } catch (e) {
      debugPrint('Error updating trainee record: $e');
      rethrow;
    }
  }
  /// Update trainee progress
  Future<void> updateTraineeProgress({
    required String studentId,
    required String applicationId,
    required int progress,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final traineeRecordId = '${applicationId}_$studentId';
      final metadata = {
        'progress': progress,
        'lastUpdated': DateTime.now().toIso8601String(),
        'hasStarted': progress > 0,
        ...?additionalMetadata,
      };

      await _firestore
          .collection(traineesCollection)
          .doc(traineeRecordId)
          .update({
        'metadata': metadata,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating trainee progress: $e');
      rethrow;
    }
  }

  /// Update student's document with trainee record reference
  Future<void> _updateStudentWithTraineeRecord(
      String studentId,
      String traineeRecordId,
      ) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(studentId)
          .update({
        'traineeRecordId': traineeRecordId,
        'hasActiveTraineeRecord': true,
        'traineeRecordCreatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating student with trainee record: $e');
      // Don't rethrow as this is not critical
    }
  }


  /// Complete trainee record (convenience method)
  Future<void> completeTraineeRecord(String studentId, String applicationId) async {
    await updateTraineeRecordStatus(
      studentId: studentId,
      applicationId: applicationId,
      newStatus: 'completed',
      endDate: DateTime.now(),
    );
  }

  /// Terminate trainee record
  Future<void> terminateTraineeRecord(
      String studentId,
      String applicationId, {
        required String reason,
      }) async {
    try {
      final traineeRecordId = '${applicationId}_$studentId';

      await _firestore
          .collection(traineesCollection)
          .doc(traineeRecordId)
          .update({
        'status': 'terminated',
        'terminationReason': reason,
        'terminatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(studentId)
          .update({
        'hasActiveTraineeRecord': false,
        'lastTraineeRecordId': traineeRecordId,
      });
    } catch (e) {
      debugPrint('Error terminating trainee record: $e');
      rethrow;
    }
  }

  /// Delete trainee record (use with caution)
  Future<void> deleteTraineeRecord(String studentId, String applicationId) async {
    try {
      final traineeRecordId = '${applicationId}_$studentId';

      await _firestore
          .collection(traineesCollection)
          .doc(traineeRecordId)
          .delete();

      await _firestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(studentId)
          .update({
        'traineeRecordId': FieldValue.delete(),
        'hasActiveTraineeRecord': false,
      });
    } catch (e) {
      debugPrint('Error deleting trainee record: $e');
      rethrow;
    }
  }
}