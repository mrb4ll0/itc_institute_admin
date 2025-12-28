// services/trainee_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../model/studentApplication.dart';
import '../../model/traineeRecord.dart';
import '../firebase/company_cloud.dart';


/*

==========================================================
                    TRAINEE SERVICE
==========================================================

WORKFLOW OVERVIEW:
----------------------------------------
1. Student Applies → Company_Cloud application system
2. Company Reviews → getPendingApplications() from Company_Cloud
3. Company Accepts → createTraineeFromApplication() creates TraineeRecord
4. Training Progresses → TraineeService manages trainee lifecycle
5. Training Completes → Status updates in both systems

COLLECTIONS USED:
----------------------------------------
1. Applications: users/companies/companies/{companyId}/IT/{internshipId}/applications/
   - Managed by Company_Cloud
   - Status: pending/accepted/rejected

2. Trainees: trainees/{traineeId}
   - Managed by TraineeService
   - Status: pending/accepted/active/completed/terminated/withdrawn

3. Company Lists: users/companies/companies/{companyId}
   - Contains: pendingApplications, acceptedTrainees, currentTrainees, completedTrainees, etc.

STATUS TRANSITIONS:
----------------------------------------
Application Status (Company_Cloud):
  pending → accepted → [No further changes]

Trainee Status (TraineeService):
  pending → accepted → active → completed
                              ├──> terminated (early end)
                              └──> withdrawn (student leaves)

DATA FLOW:
----------------------------------------
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Student Applies │────▶│  Pending Applications  │────▶│  Company Reviews │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                              │
                              ▼ (Accepted)
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│ Trainee Created  │◀────│   Accept Application   │◀────│  Company Accepts │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                              │
                              ▼ (Started)
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Active Trainee │◀────│    Start Training     │◀────│  Training Starts │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                              │
                              ▼ (Completed)
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│ Completed Trainee│◀────│  Complete Training    │◀────│ Training Ends   │
└─────────────────┘     └──────────────────────┘     └─────────────────┘

METHOD CATEGORIES:
----------------------------------------
A. INITIAL ACCEPTANCE
   - createTraineeFromApplication()  # Converts application to trainee

B. STATUS MANAGEMENT
   - startTraining()         # accepted → active
   - completeTraining()      # active → completed
   - terminateTraining()     # active → terminated (company-initiated)
   - studentWithdraw()       # active → withdrawn (student-initiated)

C. PROGRESS TRACKING
   - updateProgress()        # Update progress percentage (0-100)
   - addMilestone()          # Add training milestones
   - addEvaluation()         # Add performance evaluations

D. SUPERVISOR MANAGEMENT
   - addSupervisor()         # Assign supervisor to trainee
   - removeSupervisor()      # Remove supervisor from trainee
   - getSupervisedTrainees() # Get all trainees supervised by someone

E. QUERY METHODS
   - getCompanyTrainees()    # Get all trainees for a company
   - getTraineesByStatus()   # Get trainees filtered by status
   - getCurrentTrainees()    # Get active trainees
   - getUpcomingTrainees()   # Get accepted but not started trainees
   - getPendingTrainees()    # Get pending applications (via Company_Cloud)

F. STREAM METHODS (Real-time)
   - streamCompanyTrainees()     # All trainees for company
   - streamCurrentTrainees()     # Active trainees
   - streamUpcomingTrainees()    # Upcoming trainees
   - streamPendingApplications() # Pending applications

G. UTILITY METHODS
   - getTrainee()                     # Get trainee by ID
   - getTraineeByStudentAndCompany()  # Find trainee by student+company
   - getTraineeStatistics()           # Analytics and stats
   - getTraineesEndingSoon()          # Ending in next 7 days
   - getTraineesStartingSoon()        # Starting in next 7 days
   - hasActiveTraining()              # Check if student has active training
   - exportTraineeData()              # Export for reporting
   - getTraineeTimeline()             # Get activity history

H. BULK OPERATIONS
   - bulkUpdateTraineeStatuses()      # Update multiple trainees at once
   - updateTraineeInfo()              # Update trainee details

==========================================================
                    USAGE EXAMPLES
==========================================================

EXAMPLE 1: Accept an application and create trainee
----------------------------------------
await traineeService.createTraineeFromApplication(
  application: application,
  companyId: companyId,
  companyName: companyName,
  department: 'Software Engineering',
  role: 'Development Intern',
);

EXAMPLE 2: Start training for an accepted trainee
----------------------------------------
await traineeService.startTraining(traineeId);

EXAMPLE 3: Update progress and add milestone
----------------------------------------
await traineeService.updateProgress(traineeId, 75.0);
await traineeService.addMilestone(traineeId, {
  'title': 'Completed Module 3',
  'description': 'Successfully completed advanced topics',
  'date': DateTime.now(),
  'score': 95,
});

EXAMPLE 4: Complete training
----------------------------------------
await traineeService.completeTraining(traineeId);

EXAMPLE 5: Get current trainees for display
----------------------------------------
List<TraineeRecord> currentTrainees = await traineeService.getCurrentTrainees(companyId);

EXAMPLE 6: Real-time monitoring
----------------------------------------
StreamBuilder<List<TraineeRecord>>(
  stream: traineeService.streamCurrentTrainees(companyId),
  builder: (context, snapshot) {
    // Update UI in real-time
  },
)

==========================================================
                    INTEGRATION NOTES
==========================================================

1. Application data remains in Company_Cloud collections
2. Trainee data is stored separately in 'trainees' collection
3. Company lists are updated in both systems for consistency
4. Status changes should be made through appropriate methods
5. Always use try-catch for error handling

For questions or issues, refer to the workflow diagram above.

*/


class TraineeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Company_Cloud _companyCloud = Company_Cloud(); // Use your existing Company_Cloud

  // Collection references - matching your existing structure
  CollectionReference get _traineesRef => _firestore.collection('trainees');

  // Applications collection - using your existing structure
  CollectionReference get _applicationsRef => _firestore
      .collection('users')
      .doc('companies')
      .collection('companies');

  // Internships collection - using your existing structure
  CollectionReference get _internshipsRef => _firestore
      .collection('users')
      .doc('companies')
      .collection('companies');

  CollectionReference get _companiesRef => _firestore
      .collection('users')
      .doc('companies')
      .collection('companies');

  CollectionReference get _studentsRef => _firestore
      .collection('users')
      .doc('students')
      .collection('students');

  // Helper method to create application document ID with company prefix
  String _createApplicationId(String companyId, String applicationId, {String? traineeId}) {
    if (traineeId != null && traineeId.isNotEmpty) {
      return '${companyId}_${traineeId}_$applicationId';
    }
    return '${companyId}_$applicationId';
  }

  // Create trainee record when application is accepted
  Future<TraineeRecord?> createTraineeFromApplication({
    required StudentApplication application,
    required String companyId,
    required String companyName,
    DateTime? startDate,
    DateTime? endDate,
    String department = '',
    String role = '',
    String description = '',
    bool fromUpdateStatus = false,
    String status = "accepted"
  }) async {
    try {
      debugPrint('Creating trainee record for student: ${application.student.uid}');

      // Generate a unique ID for the trainee record
      final traineeId = '${application.student.uid}_${companyId}_${DateTime.now().millisecondsSinceEpoch}';

      // Parse dates from application
      final parsedStartDate = startDate ?? _parseStartDate(application);
      final parsedEndDate = endDate ?? _parseEndDate(application);

      final traineeRecord = TraineeRecord(
        imageUrl: application.student.imageUrl,
        id: traineeId,
        studentId: application.student.uid,
        studentName: application.student.fullName,
        companyId: companyId,
        companyName: companyName,
        applicationId: application.id,
        status: switchStatus(status),
        startDate: parsedStartDate,
        endDate: parsedEndDate,
        department: department,
        role: role,
        description: description,
        requirements: application.durationDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notes: {}
      );

      // Save to Firestore
      await _traineesRef.doc(traineeId).set(traineeRecord.toMap());

      // Update company's trainee lists using your existing Company_Cloud
      await _updateCompanyTraineeLists(companyId, application.student.uid, status);

      // Update application status using your existing Company_Cloud
      if(!fromUpdateStatus) {
        await _companyCloud.updateApplicationStatus(
          companyId: companyId,
          internshipId: application.internship.id!,
          studentId: application.student.uid,
          status: 'accepted',
          application: application,
        );
      }

      debugPrint('Trainee record created successfully: $traineeId');
      return traineeRecord;
    } catch (e, stackTrace) {
      debugPrint('Error creating trainee record: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  TraineeStatus switchStatus(String status)
  {
    TraineeStatus statuss = TraineeStatus.pending;
    switch(status)
        {
      case 'accepted':
           statuss = TraineeStatus.accepted;
          break;
      case 'rejected':
          statuss = TraineeStatus.rejected;
          break;
    }
    return statuss;
  }

  // Get pending applications using your existing Company_Cloud
  Future<List<StudentApplication>> getPendingApplications(String companyId) async {
    try {
      return await _companyCloud.getPendingApplications(companyId);
    } catch (e) {
      debugPrint('Error getting pending applications: $e');
      return [];
    }
  }

  // Get accepted applications using your existing Company_Cloud
  Future<List<StudentApplication>> getAcceptedApplications(String companyId) async {
    try {
      return await _companyCloud.getAcceptedApplications(companyId);
    } catch (e) {
      debugPrint('Error getting accepted applications: $e');
      return [];
    }
  }

  // Get applications that need attention (mixed status)
  Future<List<StudentApplication>> getApplicationsForReview(String companyId) async {
    try {
      // Get all applications
      final allApplications = await _companyCloud.studentInternshipApplicationsForCompany(companyId);

      // Filter applications that need review (pending or require attention)
      return allApplications.where((app) {
        final status = app.applicationStatus.toLowerCase();
        return status == 'pending' ||
            status == 'review_required' ||
            status == 'needs_attention';
      }).toList();
    } catch (e) {
      debugPrint('Error getting applications for review: $e');
      return [];
    }
  }

  // Update application status (wrapper around your existing method)
  Future<bool> updateApplicationStatus({
    required String companyId,
    required String internshipId,
    required String studentId,
    required String status,
    required StudentApplication application,
  }) async {
    try {
      await _companyCloud.updateApplicationStatus(
        companyId: companyId,
        internshipId: internshipId,
        studentId: studentId,
        status: status,
        application: application,
      );
      return true;
    } catch (e) {
      debugPrint('Error updating application status: $e');
      return false;
    }
  }

  DateTime? _parseStartDate(StudentApplication application) {
    final duration = application.durationDetails;
    if (duration.containsKey('startDate')) {
      final startDate = duration['startDate'];
      if (startDate is DateTime) return startDate;
      if (startDate is String) return DateTime.tryParse(startDate);
    }
    return DateTime.now().add(const Duration(days: 7)); // Default: start in 1 week
  }

  DateTime? _parseEndDate(StudentApplication application) {
    final duration = application.durationDetails;
    if (duration.containsKey('endDate')) {
      final endDate = duration['endDate'];
      if (endDate is DateTime) return endDate;
      if (endDate is String) return DateTime.tryParse(endDate);
    }

    // Calculate from duration if available
    final startDate = _parseStartDate(application) ?? DateTime.now();
    final durationDays = duration['durationInDays'] ?? 90; // Default: 90 days
    return startDate.add(Duration(days: durationDays));
  }

  Future<void> _updateCompanyTraineeLists(
      String companyId,
      String studentId,
      String status
      ) async {
    try {
      final companyRef = _companiesRef.doc(companyId);
      final companyDoc = await companyRef.get();
      if (!companyDoc.exists) return;

      final data = companyDoc.data() as Map<String, dynamic>;
      final currentAccepted = List<String>.from(data['acceptedTrainees'] ?? []);
      final currentActive = List<String>.from(data['currentTrainees'] ?? []);
      final currentCompleted = List<String>.from(data['completedTrainees'] ?? []);

      // Remove from all lists first
      final updatedAccepted = List<String>.from(currentAccepted)..remove(studentId);
      final updatedActive = List<String>.from(currentActive)..remove(studentId);
      final updatedCompleted = List<String>.from(currentCompleted)..remove(studentId);

      // Add to appropriate list
      switch (status.toLowerCase()) {
        case 'accepted':
          updatedAccepted.add(studentId);
          break;
        case 'active':
          updatedActive.add(studentId);
          break;
        case 'completed':
          updatedCompleted.add(studentId);
          break;
      }

      await companyRef.update({
        'acceptedTrainees': updatedAccepted,
        'currentTrainees': updatedActive,
        'completedTrainees': updatedCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating company lists: $e');
    }
  }

  // Get all trainees for a company
  Future<List<TraineeRecord>> getCompanyTrainees(String companyId) async {
    try {
      final query = await _traineesRef
          .where('companyId', isEqualTo: companyId)
          .orderBy('updatedAt', descending: true)
          .get();

      return query.docs.map((doc) {
        return TraineeRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting company trainees: $e');
      return [];
    }
  }

  // Get trainees by status
  Future<List<TraineeRecord>> getTraineesByStatus(
      String companyId,
      TraineeStatus status
      ) async {
    try {
      final query = await _traineesRef
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: status.name)
          .orderBy('startDate', descending: false)
          .get();

      return query.docs.map((doc) {
        debugPrint("doc is string ${doc.data() is Map<String,dynamic>}");
        return TraineeRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e,s) {
      debugPrintStack(stackTrace: s);
      debugPrint('Error getting trainees by status: $e');
      return [];
    }
  }

  // Add to TraineeService class
  Future<List<dynamic>> getAllPendingApplications(String companyId) async {
    try {
      // Get pending applications from Company_Cloud
      final companyApplications = await _companyCloud.getPendingApplications(companyId);

      // Get pending trainees from TraineeService
      final pendingTrainees = await getTraineesByStatus(companyId, TraineeStatus.pending);

      // Combine both lists
      final allPending = <dynamic>[];

      // Add Company_Cloud applications
      allPending.addAll(companyApplications);

      // Add TraineeService pending trainees
      allPending.addAll(pendingTrainees);

      // Sort by date (most recent first)
      allPending.sort((a, b) {
        final dateA = a is StudentApplication ? a.applicationDate : (a as TraineeRecord).createdAt;
        final dateB = b is StudentApplication ? b.applicationDate : (b as TraineeRecord).createdAt;
        return dateB.compareTo(dateA);
      });

      return allPending;
    } catch (e) {
      debugPrint('Error getting all pending applications: $e');
      return [];
    }
  }
  // Add to TraineeService class
  Future<TraineeRecord?> createPendingTraineeFromApplication({
    required StudentApplication application,
    required String companyId,
    required String companyName,
  }) async {
    try {
      debugPrint('Creating pending trainee record for student: ${application.student.uid}');

      // Generate a unique ID for the trainee record
      final traineeId = '${application.student.uid}_${companyId}_${DateTime.now().millisecondsSinceEpoch}';

      // Parse dates from application
      final parsedStartDate = _parseStartDate(application);
      final parsedEndDate = _parseEndDate(application);

      final traineeRecord = TraineeRecord(
        imageUrl: application.student.imageUrl,
        id: traineeId,
        studentId: application.student.uid,
        studentName: application.student.fullName,
        companyId: companyId,
        companyName: companyName,
        applicationId: application.id,
        status: TraineeStatus.pending, // Set as pending
        startDate: parsedStartDate,
        endDate: parsedEndDate,
        department: application.internship.department ?? '',
        role: application.internship.title ?? '',
        description: application.internship.description ?? '',
        requirements: application.durationDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notes: {}

      );

      // Save to Firestore
      await _traineesRef.doc(traineeId).set(traineeRecord.toMap());

      // Update company's pending trainees list
      await _companiesRef.doc(companyId).update({
        'pendingTrainees': FieldValue.arrayUnion([traineeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Pending trainee record created successfully: $traineeId');
      return traineeRecord;
    } catch (e, stackTrace) {
      debugPrint('Error creating pending trainee record: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }



  // Get current active trainees
  Future<List<TraineeRecord>> getCurrentTrainees(String companyId) async {
    return getTraineesByStatus(companyId, TraineeStatus.active);
  }

  // Get upcoming trainees (accepted but not started)
  Future<List<TraineeRecord>> getUpcomingTrainees(String companyId) async {
    return getTraineesByStatus(companyId, TraineeStatus.accepted);
  }

  // Get pending trainees (applications not yet accepted)
  Future<List<TraineeRecord>> getPendingTrainees(String companyId) async {
    return getTraineesByStatus(companyId, TraineeStatus.pending);
  }

  // Start a trainee's training
  Future<bool> startTraining(String traineeId) async {
    try {
      final traineeDoc = await _traineesRef.doc(traineeId).get();
      if (!traineeDoc.exists) return false;

      final data = traineeDoc.data() as Map<String, dynamic>;
      final trainee = TraineeRecord.fromFirestore(data, traineeId);

      // Update trainee record
      await _traineesRef.doc(traineeId).update({
        'status': TraineeStatus.active.name,
        'actualStartDate': DateTime.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update company lists
      await _updateCompanyTraineeLists(trainee.companyId, trainee.studentId, 'active');

      return true;
    } catch (e) {
      debugPrint('Error starting training: $e');
      return false;
    }
  }

  // Complete training
  Future<bool> completeTraining(String traineeId) async {
    try {
      final traineeDoc = await _traineesRef.doc(traineeId).get();
      if (!traineeDoc.exists) return false;

      final data = traineeDoc.data() as Map<String, dynamic>;
      final trainee = TraineeRecord.fromFirestore(data, traineeId);

      // Update trainee record
      await _traineesRef.doc(traineeId).update({
        'status': TraineeStatus.completed.name,
        'actualEndDate': DateTime.now(),
        'progress': 100.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update company lists
      await _updateCompanyTraineeLists(trainee.companyId, trainee.studentId, 'completed');

      return true;
    } catch (e) {
      debugPrint('Error completing training: $e');
      return false;
    }
  }

  // Terminate training early
  Future<bool> terminateTraining(String traineeId, String reason) async {
    try {
      final traineeDoc = await _traineesRef.doc(traineeId).get();
      if (!traineeDoc.exists) return false;

      final data = traineeDoc.data() as Map<String, dynamic>;
      final trainee = TraineeRecord.fromFirestore(data, traineeId);

      // Update trainee record
      await _traineesRef.doc(traineeId).update({
        'status': TraineeStatus.terminated.name,
        'actualEndDate': DateTime.now(),
        'terminationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update company lists
      await _companiesRef.doc(trainee.companyId).update({
        'terminatedTrainees': FieldValue.arrayUnion([trainee.studentId]),
        'currentTrainees': FieldValue.arrayRemove([trainee.studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error terminating training: $e');
      return false;
    }
  }

  // Student withdraws from training
  Future<bool> studentWithdraw(String traineeId, String reason) async {
    try {
      final traineeDoc = await _traineesRef.doc(traineeId).get();
      if (!traineeDoc.exists) return false;

      final data = traineeDoc.data() as Map<String, dynamic>;
      final trainee = TraineeRecord.fromFirestore(data, traineeId);

      // Update trainee record
      await _traineesRef.doc(traineeId).update({
        'status': TraineeStatus.withdrawn.name,
        'actualEndDate': DateTime.now(),
        'withdrawalReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update company lists
      await _companiesRef.doc(trainee.companyId).update({
        'withdrawnTrainees': FieldValue.arrayUnion([trainee.studentId]),
        'currentTrainees': FieldValue.arrayRemove([trainee.studentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error processing student withdrawal: $e');
      return false;
    }
  }

  // Update trainee progress
  Future<bool> updateProgress(String traineeId, double progress) async {
    try {
      await _traineesRef.doc(traineeId).update({
        'progress': progress.clamp(0.0, 100.0),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating progress: $e');
      return false;
    }
  }

  // Add supervisor to trainee
  Future<bool> addSupervisor(String traineeId, String supervisorId) async {
    try {
      await _traineesRef.doc(traineeId).update({
        'supervisorIds': FieldValue.arrayUnion([supervisorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding supervisor: $e');
      return false;
    }
  }

  // Remove supervisor from trainee
  Future<bool> removeSupervisor(String traineeId, String supervisorId) async {
    try {
      await _traineesRef.doc(traineeId).update({
        'supervisorIds': FieldValue.arrayRemove([supervisorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing supervisor: $e');
      return false;
    }
  }

  // Get trainees supervised by a specific supervisor
  Future<List<TraineeRecord>> getSupervisedTrainees(String supervisorId) async {
    try {
      final query = await _traineesRef
          .where('supervisorIds', arrayContains: supervisorId)
          .where('status', whereIn: [TraineeStatus.active.name, TraineeStatus.accepted.name])
          .orderBy('startDate', descending: false)
          .get();

      return query.docs.map((doc) {
        return TraineeRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting supervised trainees: $e');
      return [];
    }
  }

  // Add milestone
  Future<bool> addMilestone(String traineeId, Map<String, dynamic> milestone) async {
    try {
      await _traineesRef.doc(traineeId).update({
        'milestones': FieldValue.arrayUnion([milestone]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding milestone: $e');
      return false;
    }
  }

  // Add evaluation
  Future<bool> addEvaluation(String traineeId, Map<String, dynamic> evaluation) async {
    try {
      await _traineesRef.doc(traineeId).update({
        'evaluations': FieldValue.arrayUnion([evaluation]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding evaluation: $e');
      return false;
    }
  }

  // Stream of trainees for a company (real-time updates)
  Stream<List<TraineeRecord>> streamCompanyTrainees(String companyId) {
    return _traineesRef
        .where('companyId', isEqualTo: companyId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TraineeRecord.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // Stream of current trainees
  Stream<List<TraineeRecord>> streamCurrentTrainees(String companyId) {
    return _traineesRef
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: TraineeStatus.active.name)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TraineeRecord.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // Stream of upcoming trainees
  Stream<List<TraineeRecord>> streamUpcomingTrainees(String companyId) {
    return _traineesRef
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: TraineeStatus.accepted.name)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TraineeRecord.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // Stream of pending applications (using your Company_Cloud's stream)
  Stream<List<StudentApplication>> streamPendingApplications(String companyId) {
    // Use your existing Company_Cloud's stream method
    return _companyCloud.studentInternshipApplicationsForCompanyStream(companyId)
        .map((applications) {
      return applications.where((app) => app.isPending).toList();
    });
  }

  // Get trainee by ID
  Future<TraineeRecord?> getTrainee(String traineeId) async {
    try {
      final doc = await _traineesRef.doc(traineeId).get();
      if (!doc.exists) return null;
      return TraineeRecord.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      debugPrint('Error getting trainee: $e');
      return null;
    }
  }

  // Get trainee by student ID and company ID
  Future<TraineeRecord?> getTraineeByStudentAndCompany(String studentId, String companyId) async {
    try {
      final query = await _traineesRef
          .where('studentId', isEqualTo: studentId)
          .where('companyId', isEqualTo: companyId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return TraineeRecord.fromFirestore(
        query.docs.first.data() as Map<String, dynamic>,
        query.docs.first.id,
      );
    } catch (e) {
      debugPrint('Error getting trainee by student and company: $e');
      return null;
    }
  }

  // Get trainee statistics for a company
  Future<Map<String, dynamic>> getTraineeStatistics(String companyId) async {
    try {
      final trainees = await getCompanyTrainees(companyId);

      int total = trainees.length;
      int pending = trainees.where((t) => t.status == TraineeStatus.pending).length;
      int accepted = trainees.where((t) => t.status == TraineeStatus.accepted).length;
      int active = trainees.where((t) => t.status == TraineeStatus.active).length;
      int completed = trainees.where((t) => t.status == TraineeStatus.completed).length;
      int terminated = trainees.where((t) => t.status == TraineeStatus.terminated).length;
      int withdrawn = trainees.where((t) => t.status == TraineeStatus.withdrawn).length;

      // Calculate average progress for active trainees
      final activeTrainees = trainees.where((t) => t.status == TraineeStatus.active);
      final avgProgress = activeTrainees.isNotEmpty
          ? activeTrainees.map((t) => t.progress).reduce((a, b) => a + b) / activeTrainees.length
          : 0.0;

      // Count trainees with supervisors
      final supervisedCount = trainees.where((t) => t.supervisorIds.isNotEmpty).length;

      // Count overdue trainees (past end date but not completed)
      final now = DateTime.now();
      final overdueCount = trainees.where((t) {
        return t.endDate != null &&
            t.endDate!.isBefore(now) &&
            t.status != TraineeStatus.completed &&
            t.status != TraineeStatus.terminated &&
            t.status != TraineeStatus.withdrawn;
      }).length;

      return {
        'total': total,
        'pending': pending,
        'accepted': accepted,
        'active': active,
        'completed': completed,
        'terminated': terminated,
        'withdrawn': withdrawn,
        'averageProgress': avgProgress.toStringAsFixed(1),
        'supervisedCount': supervisedCount,
        'unsupervisedCount': total - supervisedCount,
        'overdueCount': overdueCount,
        'completionRate': total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0.0',
        'activeRate': total > 0 ? (active / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      debugPrint('Error getting trainee statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'active': 0,
        'completed': 0,
        'terminated': 0,
        'withdrawn': 0,
        'averageProgress': '0.0',
        'supervisedCount': 0,
        'unsupervisedCount': 0,
        'overdueCount': 0,
        'completionRate': '0.0',
        'activeRate': '0.0',
      };
    }
  }

  // Get trainees ending soon (within next 7 days)
  Future<List<TraineeRecord>> getTraineesEndingSoon(String companyId) async {
    try {
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      final query = await _traineesRef
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: [TraineeStatus.active.name, TraineeStatus.accepted.name])
          .orderBy('endDate', descending: false)
          .get();

      return query.docs
          .map((doc) => TraineeRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((trainee) => trainee.endDate != null &&
          trainee.endDate!.isAfter(now) &&
          trainee.endDate!.isBefore(weekFromNow))
          .toList();
    } catch (e) {
      debugPrint('Error getting trainees ending soon: $e');
      return [];
    }
  }

  // Get trainees starting soon (within next 7 days)
  Future<List<TraineeRecord>> getTraineesStartingSoon(String companyId) async {
    try {
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));

      final query = await _traineesRef
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: TraineeStatus.accepted.name)
          .orderBy('startDate', descending: false)
          .get();

      return query.docs
          .map((doc) => TraineeRecord.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((trainee) => trainee.startDate != null &&
          trainee.startDate!.isAfter(now) &&
          trainee.startDate!.isBefore(weekFromNow))
          .toList();
    } catch (e) {
      debugPrint('Error getting trainees starting soon: $e');
      return [];
    }
  }

  // Update trainee information
  Future<bool> updateTraineeInfo({
    required String traineeId,
    String? department,
    String? role,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? requirements,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (department != null) updateData['department'] = department;
      if (role != null) updateData['role'] = role;
      if (description != null) updateData['description'] = description;
      if (startDate != null) updateData['startDate'] = startDate;
      if (endDate != null) updateData['endDate'] = endDate;
      if (requirements != null) updateData['requirements'] = requirements;

      await _traineesRef.doc(traineeId).update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error updating trainee info: $e');
      return false;
    }
  }

  // Bulk update trainee statuses
  Future<bool> bulkUpdateTraineeStatuses(List<String> traineeIds, TraineeStatus newStatus) async {
    try {
      final batch = _firestore.batch();

      for (final traineeId in traineeIds) {
        final traineeRef = _traineesRef.doc(traineeId);

        final updateData = {
          'status': newStatus.name,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add specific dates based on status
        if (newStatus == TraineeStatus.active) {
          updateData['actualStartDate'] = DateTime.now();
        } else if (newStatus == TraineeStatus.completed ||
            newStatus == TraineeStatus.terminated ||
            newStatus == TraineeStatus.withdrawn) {
          updateData['actualEndDate'] = DateTime.now();
          if (newStatus == TraineeStatus.completed) {
            updateData['progress'] = 100.0;
          }
        }

        batch.update(traineeRef, updateData);
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error bulk updating trainee statuses: $e');
      return false;
    }
  }

  // Export trainee data
  Future<List<Map<String, dynamic>>> exportTraineeData(String companyId) async {
    try {
      final trainees = await getCompanyTrainees(companyId);

      return trainees.map((trainee) {
        return {
          'traineeId': trainee.id,
          'studentId': trainee.studentId,
          'studentName': trainee.studentName,
          'companyId': trainee.companyId,
          'companyName': trainee.companyName,
          'status': trainee.status.displayName,
          'startDate': trainee.startDate?.toIso8601String(),
          'endDate': trainee.endDate?.toIso8601String(),
          'actualStartDate': trainee.actualStartDate?.toIso8601String(),
          'actualEndDate': trainee.actualEndDate?.toIso8601String(),
          'department': trainee.department,
          'role': trainee.role,
          'progress': trainee.progress,
          'supervisors': trainee.supervisorIds,
          'milestones': trainee.milestones.length,
          'evaluations': trainee.evaluations.length,
          'createdAt': trainee.createdAt.toIso8601String(),
          'updatedAt': trainee.updatedAt.toIso8601String(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error exporting trainee data: $e');
      return [];
    }
  }

  // Check if student has active training with company
  Future<bool> hasActiveTraining(String studentId, String companyId) async {
    try {
      final query = await _traineesRef
          .where('studentId', isEqualTo: studentId)
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: [
        TraineeStatus.accepted.name,
        TraineeStatus.active.name,
      ])
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking active training: $e');
      return false;
    }
  }

  // Get trainee timeline/activity log
  Future<List<Map<String, dynamic>>> getTraineeTimeline(String traineeId) async {
    try {
      final traineeDoc = await _traineesRef.doc(traineeId).get();
      if (!traineeDoc.exists) return [];

      final trainee = TraineeRecord.fromFirestore(
        traineeDoc.data() as Map<String, dynamic>,
        traineeId,
      );

      final timeline = <Map<String, dynamic>>[];

      // Add status changes
      timeline.add({
        'type': 'status',
        'title': 'Application Submitted',
        'description': 'Student applied for training',
        'date': trainee.createdAt,
        'status': 'pending',
      });

      if (trainee.startDate != null) {
        timeline.add({
          'type': 'date',
          'title': 'Training Scheduled',
          'description': 'Training start date set',
          'date': trainee.startDate!,
          'status': 'scheduled',
        });
      }

      if (trainee.actualStartDate != null) {
        timeline.add({
          'type': 'status',
          'title': 'Training Started',
          'description': 'Student began training',
          'date': trainee.actualStartDate!,
          'status': 'active',
        });
      }

      // Add milestones
      for (final milestone in trainee.milestones) {
        timeline.add({
          'type': 'milestone',
          'title': milestone['title'] ?? 'Milestone',
          'description': milestone['description'] ?? '',
          'date': milestone['date'] != null
              ? DateTime.tryParse(milestone['date'].toString()) ?? DateTime.now()
              : DateTime.now(),
          'status': 'milestone',
        });
      }

      if (trainee.actualEndDate != null) {
        timeline.add({
          'type': 'status',
          'title': 'Training Completed',
          'description': 'Student completed training',
          'date': trainee.actualEndDate!,
          'status': 'completed',
        });
      }

      // Sort by date
      timeline.sort((a, b) => b['date'].compareTo(a['date']));

      return timeline;
    } catch (e) {
      debugPrint('Error getting trainee timeline: $e');
      return [];
    }
  }


  Future<bool> updateTraineeStatus({
    required String traineeId,
    required TraineeStatus newStatus,
    String? reason,
    Map<String, dynamic>? additionalData,
    bool updateCompanyLists = true,
  }) async {
    try {
      final traineeDoc = await _traineesRef.doc(traineeId).get();
      if (!traineeDoc.exists) return false;

      final data = traineeDoc.data() as Map<String, dynamic>;
      final trainee = TraineeRecord.fromFirestore(data, traineeId);

      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add specific dates based on status
      if (newStatus == TraineeStatus.active) {
        updateData['actualStartDate'] = DateTime.now();
      } else if (newStatus == TraineeStatus.completed ||
          newStatus == TraineeStatus.terminated ||
          newStatus == TraineeStatus.withdrawn) {
        updateData['actualEndDate'] = DateTime.now();
        if (newStatus == TraineeStatus.completed) {
          updateData['progress'] = 100.0;
        }
      }

      // Add reason if provided
      if (reason != null && reason.isNotEmpty) {
        if (newStatus == TraineeStatus.terminated) {
          updateData['terminationReason'] = reason;
        } else if (newStatus == TraineeStatus.withdrawn) {
          updateData['withdrawalReason'] = reason;
        }

        // Also add to notes - FIXED HERE
        final currentNotes = data['notes'];
        final notes = currentNotes is List ? List<Map<String, dynamic>>.from(currentNotes) : <Map<String, dynamic>>[];

        notes.add({
          'date': DateTime.now(),
          'type': 'status_change',
          'from': trainee.status.name,
          'to': newStatus.name,
          'note': reason,
        });
        updateData['notes'] = notes;
      }

      // Add any additional data
      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      // Update trainee record
      await _traineesRef.doc(traineeId).update(updateData);

      // Update company lists if requested
      if (updateCompanyLists) {
        await _updateCompanyTraineeLists(
            trainee.companyId,
            trainee.studentId,
            newStatus.name.toLowerCase()
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating trainee status: $e');
      return false;
    }
  }
  // Comprehensive method to update application status AND trainee collection
  Future<bool> updateApplicationStatusWithTraineeSync({
    required String companyId,
    required String internshipId,
    required String studentId,
    required String applicationId,
    required String status, // 'pending', 'accepted', 'rejected', 'reviewed', 'shortlisted', etc.
    String? reason,
    Map<String, dynamic>? traineeUpdateData,
  }) async {
    try {
      debugPrint('Updating application status with trainee sync: $applicationId');

      // 1. First, try to get the application to get full details
      final StudentApplication? application = await _companyCloud.getApplicationById(
          companyId,
          internshipId,
          applicationId
      );

      if (application == null) {
        debugPrint('Application not found: $applicationId');
        return false;
      }

      // 2. Update application status in Company_Cloud
      await _companyCloud.updateApplicationStatusByIds(
        companyId: companyId,
        internshipId: internshipId,
        studentId: studentId,
        applicationId: applicationId,
        status: status,
      );

      // 3. Handle trainee collection based on status
      return await _syncTraineeWithApplicationStatus(
        companyId: companyId,
        internshipId: internshipId,
        studentId: studentId,
        applicationId: applicationId,
        application: application,
        status: status,
        reason: reason,
        additionalData: traineeUpdateData,
      );

    } catch (e, stackTrace) {
      debugPrint('Error updating application status with trainee sync: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

// Helper method to sync trainee record with application status
  Future<bool> _syncTraineeWithApplicationStatus({
    required String companyId,
    required String internshipId,
    required String studentId,
    required String applicationId,
    required StudentApplication application,
    required String status,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final normalizedStatus = status.toLowerCase();

      // Check if trainee already exists
      TraineeRecord? existingTrainee = await getTraineeByStudentAndCompany(
          studentId,
          companyId
      );

      switch (normalizedStatus) {
        case 'accepted':
        // If accepted, create or update trainee record
          if (existingTrainee == null) {
            // Create new trainee record
            final newTrainee = await createTraineeFromApplication(
              application: application,
              companyId: companyId,
              companyName: application.internship.company.name,
              department: application.internship.department ?? '',
              role: application.internship.title ?? '',
              description: application.internship.description ?? '',
            );

            return newTrainee != null;
          } else {
            // Update existing trainee to accepted status
            return await updateTraineeStatus(
              traineeId: existingTrainee.id,
              newStatus: TraineeStatus.accepted,
              reason: reason ?? 'Application accepted',
              additionalData: additionalData,
            );
          }

        case 'rejected':
        // If rejected, update or create terminated trainee record
          if (existingTrainee == null) {
            // Create a terminated trainee record for tracking
            final terminatedTrainee = await _createTerminatedTraineeRecord(
              application: application,
              companyId: companyId,
              reason: reason ?? 'Application rejected',
            );
            return terminatedTrainee != null;
          } else {
            // Update existing trainee to terminated status
            return await updateTraineeStatus(
              traineeId: existingTrainee.id,
              newStatus: TraineeStatus.terminated,
              reason: reason ?? 'Application rejected',
              additionalData: additionalData,
            );
          }

        case 'pending':
        // If pending, create or update pending trainee record
          if (existingTrainee == null) {
            // Create pending trainee record
            final pendingTrainee = await createPendingTraineeFromApplication(
              application: application,
              companyId: companyId,
              companyName: application.internship.company.name,
            );
            return pendingTrainee != null;
          } else {
            // Update existing trainee to pending status
            return await updateTraineeStatus(
              traineeId: existingTrainee.id,
              newStatus: TraineeStatus.pending,
              reason: reason ?? 'Application pending review',
              additionalData: additionalData,
            );
          }

        case 'shortlisted':
        case 'reviewed':
        case 'interview_scheduled':
        // For intermediate statuses, update trainee with status note
          if (existingTrainee == null) {
            // Create trainee record with intermediate status
            final intermediateTrainee = await _createTraineeWithCustomStatus(
              application: application,
              companyId: companyId,
              status: TraineeStatus.pending, // Keep as pending
              statusNote: 'Application $status',
              additionalData: additionalData,
            );
            return intermediateTrainee != null;
          } else {
            // Add status note to existing trainee - FIXED HERE
            final traineeDoc = await _traineesRef.doc(existingTrainee.id).get();
            final data = traineeDoc.data() as Map<String, dynamic>;
            final currentNotes = data['notes'];
            final notes = currentNotes is List ? List<Map<String, dynamic>>.from(currentNotes) : <Map<String, dynamic>>[];

            notes.add({
              'date': DateTime.now(),
              'status': status,
              'note': reason ?? 'Application $status',
            });

            await _traineesRef.doc(existingTrainee.id).update({
              'notes': notes,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastStatus': status,
            });

            return true;
          }

        case 'withdrawn':
        // If student withdrew application
          if (existingTrainee != null) {
            return await updateTraineeStatus(
              traineeId: existingTrainee.id,
              newStatus: TraineeStatus.withdrawn,
              reason: reason ?? 'Application withdrawn by student',
              additionalData: additionalData,
            );
          }
          return true; // No trainee record to update

        default:
        // For other statuses, just update notes if trainee exists
          if (existingTrainee != null) {
            final traineeDoc = await _traineesRef.doc(existingTrainee.id).get();
            final data = traineeDoc.data() as Map<String, dynamic>;
            final currentNotes = data['notes'];
            final notes = currentNotes is List ? List<Map<String, dynamic>>.from(currentNotes) : <Map<String, dynamic>>[];

            notes.add({
              'date': DateTime.now(),
              'status': status,
              'note': 'Application status changed to $status',
            });

            await _traineesRef.doc(existingTrainee.id).update({
              'notes': notes,
              'updatedAt': FieldValue.serverTimestamp(),
              'lastStatus': status,
            });
          }
          return true;
      }
    } catch (e, stackTrace) {
      debugPrint('Error syncing trainee with application status: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
// Helper to create terminated trainee record
  Future<TraineeRecord?> _createTerminatedTraineeRecord({
    required StudentApplication application,
    required String companyId,
    required String reason,
  }) async {
    try {
      final traineeId = '${application.student.uid}_${companyId}_${DateTime.now().millisecondsSinceEpoch}';

      final traineeRecord = TraineeRecord(
        imageUrl: application.student.imageUrl,
        notes: {"reason":reason},
        id: traineeId,
        studentId: application.student.uid,
        studentName: application.student.fullName,
        companyId: companyId,
        companyName: application.internship.company.name,
        applicationId: application.id,
        status: TraineeStatus.terminated,
        startDate: null,
        endDate: null,
        actualEndDate: DateTime.now(),
        department: application.internship.department ?? '',
        role: application.internship.title ?? '',
        description: 'Application rejected',
        requirements: application.durationDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _traineesRef.doc(traineeId).set(traineeRecord.toMap());

      // Update company's terminated trainees list
      await _companiesRef.doc(companyId).update({
        'terminatedTrainees': FieldValue.arrayUnion([traineeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return traineeRecord;
    } catch (e) {
      debugPrint('Error creating terminated trainee record: $e');
      return null;
    }
  }

// Helper to create trainee with custom status
  Future<TraineeRecord?> _createTraineeWithCustomStatus({
    required StudentApplication application,
    required String companyId,
    required TraineeStatus status,
    String? statusNote,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final traineeId = '${application.student.uid}_${companyId}_${DateTime.now().millisecondsSinceEpoch}';

      final traineeRecord = TraineeRecord(
        imageUrl: application.student.imageUrl,
        notes: {"statusNote":statusNote},
        id: traineeId,
        studentId: application.student.uid,
        studentName: application.student.fullName,
        companyId: companyId,
        companyName: application.internship.company.name,
        applicationId: application.id,
        status: status,
        startDate: _parseStartDate(application),
        endDate: _parseEndDate(application),
        department: application.internship.department ?? '',
        role: application.internship.title ?? '',
        description: application.internship.description ?? '',
        requirements: application.durationDetails,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final traineeData = traineeRecord.toMap();

      // Add custom notes if provided
      if (statusNote != null) {
        traineeData['notes'] = [
          {
            'date': DateTime.now(),
            'note': statusNote,
            'type': 'status_update',
          }
        ];
      }

      // Add any additional data
      if (additionalData != null) {
        traineeData.addAll(additionalData);
      }

      await _traineesRef.doc(traineeId).set(traineeData);

      // Update company lists based on status
      final statusKey = status.name.toLowerCase();
      await _companiesRef.doc(companyId).update({
        '${statusKey}Trainees': FieldValue.arrayUnion([traineeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return traineeRecord;
    } catch (e) {
      debugPrint('Error creating trainee with custom status: $e');
      return null;
    }
  }


}