import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/firebase_cloud_storage/firebase_cloud.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/ActionLogger.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart' hide NotificationType;
import 'package:itc_institute_admin/itc_logic/service/tranineeService.dart';
import 'package:rxdart/rxdart.dart';

import '../../model/RecentActions.dart';
import '../../model/company.dart';
import '../../model/companyForm.dart';
import '../../model/internship_model.dart';
import '../../model/localNotification.dart';
import '../../model/review.dart';
import '../../model/student.dart';
import '../../model/studentApplication.dart';
import '../../view/home/industrailTraining/applications/studentWithLatestApplication.dart';
import 'general_cloud.dart';

class Company_Cloud {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  String usersCollection = "users";
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();
  final ActionLogger actionLogger = ActionLogger();
  final FirebaseUploader _cloudStorage = FirebaseUploader();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  Future<void> postInternship(IndustrialTraining internship,{required bool isAuthority}) async {
    // Verify the user is a company
    final company = await _itcFirebaseLogic.getCompany(internship.company.id);
    if (company == null) throw Exception("Current user is not a company");

    // Reference to nested internship collection
    final internshipRef = _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(company.id)
        .collection('IT')
        .doc(); // Auto-generate ID
    debugPrint("internshipRef is $internshipRef");
    final internshipData = {
      ...internship.toMap(),
      'postedAt': FieldValue.serverTimestamp(),
    };
    try {
      await internshipRef.set(internshipData);
      RecentAction recentAction = RecentAction(
        id: "",
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: company.name,
        userEmail: company.email,
        userRole: company.role,
        actionType: "Creation",
        entityType: "Industrial Training",
        entityId: internshipRef.id,
        entityName: internship.title,
        description: "Industrial Training created",
        timestamp: DateTime.now(),
      );
      await actionLogger.logAction(
        recentAction,
        companyId: FirebaseAuth.instance.currentUser!.uid,
        isAuthority: isAuthority
      );
    } catch (e, s) {
      debugPrint(s.toString());
    }
  }

  // In your Company_Cloud class, modify the stream method

  Future<void> updateInternship(IndustrialTraining internship,{required bool isAuthority}) async {
    try {
      // Verify the user is a company
      final company = await _itcFirebaseLogic.getCompany(internship.company.id);
      if (company == null) throw Exception("Current user is not a company");

      // Check if internship ID is provided
      if (internship.id == null || internship.id!.isEmpty) {
        throw Exception("Internship ID is required for update");
      }

      // Reference to the existing internship document
      final internshipRef = _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(company.id)
          .collection('IT')
          .doc(internship.id!);

      debugPrint("Updating internship at: $internshipRef");

      // Create update data - preserve important fields
      final updateData = {
        ...internship.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'postedAt': FieldValue.serverTimestamp(), // Update postedAt as well
      };

      // Remove fields that shouldn't be updated
      updateData.removeWhere(
        (key, value) =>
            key == 'createdAt' || // Preserve original creation time
            key == 'applicationsCount' || // Preserve count from existing data
            key == 'id', // Don't update the ID
      );

      // Perform the update
      await internshipRef.update(updateData);

      // Log the update action
      final recentAction = RecentAction(
        id: "",
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: company.name,
        userEmail: company.email,
        userRole: company.role,
        actionType: "Update",
        entityType: "Industrial Training",
        entityId: internshipRef.id,
        entityName: internship.title,
        description: "Industrial Training updated",
        timestamp: DateTime.now(),
      );

      await actionLogger.logAction(
        isAuthority:isAuthority,
        recentAction,
        companyId: FirebaseAuth.instance.currentUser!.uid,
      );

      debugPrint("Internship updated successfully: ${internshipRef.id}");
    } catch (e, s) {
      debugPrint("Error updating internship: $e");
      debugPrint("Stack trace: $s");
      rethrow; // Re-throw the error so the UI can handle it
    }
  }

  Future<void> incrementInternshipApplicationCount(
    String companyId,
    String internshipId,
      {required bool isAuthority}
  ) async {
    try {
      // Check if IDs are provided
      if (companyId.isEmpty || internshipId.isEmpty) {
        throw Exception("Company ID and Internship ID are required");
      }

      // Reference to the internship document
      final internshipRef = _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internshipId);

      debugPrint(
        "Incrementing application count for internship: $internshipId",
      );

      // Use FieldValue.increment to atomically increase the count
      await internshipRef.update({
        'applicationsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      final company = await _itcFirebaseLogic.getCompany(companyId);
      if (company != null) {
        final recentAction = RecentAction(
          id: "",
          userId: FirebaseAuth.instance.currentUser?.uid ?? "",
          userName: company.name,
          userEmail: company.email,
          userRole: company.role,
          actionType: "Application",
          entityType: "Industrial Training",
          entityId: internshipId,
          entityName: "Internship Application",
          description: "Accepted application count incremented",
          timestamp: DateTime.now(),
        );

        await actionLogger.logAction(recentAction, companyId: companyId,isAuthority: isAuthority);
      }

      debugPrint("Application count incremented for internship: $internshipId");
    } catch (e, s) {
      debugPrint("Error incrementing application count: $e");
      debugPrint("Stack trace: $s");
      rethrow;
    }
  }

  Future<void> updateInternshipStatus(
    IndustrialTraining internship,
    String status,
      {required bool isAuthority}
  ) async {
    try {
      // Validate input parameters
      if (status.isEmpty) {
        throw Exception("Status is required for update");
      }

      if (internship.id == null || internship.id!.isEmpty) {
        throw Exception("Internship ID is required for update");
      }

      // Verify the user is a company
      final company = await _itcFirebaseLogic.getCompany(internship.company.id);
      if (company == null) throw Exception("Current user is not a company");

      // Reference to the existing internship document
      final internshipRef = _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(company.id)
          .collection('IT')
          .doc(internship.id!);

      debugPrint("Updating internship status at: $internshipRef");

      // Only update status and updatedAt - don't update postedAt for status changes
      final updateData = {
        'status': status.toLowerCase(), // Ensure consistent casing
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Perform the update
      await internshipRef.update(updateData);

      // Log the update action
      final recentAction = RecentAction(
        id: "",
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: company.name,
        userEmail: company.email,
        userRole: company.role,
        actionType: "Status Update",
        entityType: "Industrial Training",
        entityId: internshipRef.id,
        entityName: internship.title,
        description: "Status changed to: $status",
        timestamp: DateTime.now(),
      );

      await actionLogger.logAction(
        recentAction,
        companyId: FirebaseAuth.instance.currentUser!.uid,
        isAuthority: isAuthority
      );

      debugPrint("Internship status updated to '$status': ${internshipRef.id}");
    } catch (e, s) {
      debugPrint("Error updating internship status: $e");
      debugPrint("Stack trace: $s");
      rethrow;
    }
  }

  Stream<List<IndustrialTraining>> getAllCompanyInternships() {
    try {
      return _firebaseFirestore
          .collectionGroup('IT')
          .orderBy('postedAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<IndustrialTraining> internships = [];
            for (var doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;

              // The company field is already a Map, not a DocumentReference
              final companyData = data['company'] as Map<String, dynamic>?;

              if (companyData != null) {
                try {
                  // Create Company object directly from the embedded map
                  final company = Company.fromMap(companyData);

                  // Create the IndustrialTraining object
                  IndustrialTraining it = IndustrialTraining.fromMap(
                    data,
                    doc.id,
                  );
                  it.company = company;
                  internships.add(it);
                } catch (e, stackTrace) {
                  debugPrint(
                    'Error parsing company data for doc ${doc.id}: $e',
                  );
                  debugPrint('Company data: $companyData');
                }
              } else {
                debugPrint('Warning: Company data is null for doc ${doc.id}');
                // Handle null company - create a default company or skip
                IndustrialTraining it = IndustrialTraining.fromMap(
                  data,
                  doc.id,
                );
                Company? company = await _itcFirebaseLogic.getCompany(
                  it.company.id,
                );
                if (company != null) {
                  it.company = company;
                }
              }
            }
            return internships;
          })
          .handleError((error, stackTrace) {
            debugPrint('Firestore Stream Error: $error');
            debugPrint('Stack Trace: $stackTrace');
            // Return empty list to keep stream alive
            return <IndustrialTraining>[];
          });
    } catch (e, stackTrace) {
      debugPrint('Stream Creation Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return Stream.value(<IndustrialTraining>[]);
    }
  }

  Stream<List<IndustrialTraining>> getCurrentCompanyInternships(
      String companyId,
      {
        bool isAuthority = false,
        List<String>? companyIds
      }
      ) {
    try {
      // Determine which company IDs to use
      List<String> idsToQuery;

      if (isAuthority && companyIds != null && companyIds.isNotEmpty) {
        // Authority user with multiple company IDs - use all company IDs
        idsToQuery = companyIds;
      } else {
        // Non-authority user OR companyIds is null/empty - use single companyId
        idsToQuery = [companyId];
      }

      // Create streams for each company
      final streams = idsToQuery.map((currentCompanyId) {
        return _firebaseFirestore
            .collection("users")
            .doc('companies')
            .collection('companies')
            .doc(currentCompanyId)
            .collection('IT')
            .orderBy('postedAt', descending: true)
            .snapshots()
            .asyncMap((snapshot) async {
          List<IndustrialTraining> internships = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;

              // Get company data
              final companyDoc = await _firebaseFirestore
                  .collection("users")
                  .doc("companies")
                  .collection('companies')
                  .doc(currentCompanyId)
                  .get();

              if (companyDoc.exists) {
                final company = Company.fromMap(
                  companyDoc.data() as Map<String, dynamic>,
                );

                // Create the IndustrialTraining object
                IndustrialTraining it = IndustrialTraining.fromMap(
                  data,
                  doc.id,
                );
                it.company = company;
                it.applicationsCount = await getApplicationsCount(
                  currentCompanyId,
                  doc.id,
                );
                internships.add(it);
              }
            } catch (e, stackTrace) {
              debugPrint('Error processing internship ${doc.id} for company $currentCompanyId: $e');
              debugPrint('Stack Trace: $stackTrace');
              continue;
            }
          }
          return internships;
        })
            .handleError((error, stackTrace) {
          debugPrint('Firestore Stream Error for company $currentCompanyId: $error');
          debugPrint('Stack Trace: $stackTrace');
          return <IndustrialTraining>[];
        });
      });

      // Handle single vs multiple streams
      if (idsToQuery.length == 1) {
        // Single company - return the stream directly
        return streams.first;
      } else {
        // Multiple companies - merge streams without using StreamGroup
        return _mergeMultipleCompanyStreams(streams.toList());
      }
    } catch (e, stackTrace) {
      debugPrint('Stream Creation Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return Stream.value(<IndustrialTraining>[]);
    }
  }

// Helper method to merge multiple streams without StreamGroup
  Stream<List<IndustrialTraining>> _mergeMultipleCompanyStreams(
      List<Stream<List<IndustrialTraining>>> streams
      ) {
    // Create a broadcast stream controller
    final controller = StreamController<List<IndustrialTraining>>.broadcast();
    final allInternships = <IndustrialTraining>[];

    // Track active subscriptions
    final subscriptions = <StreamSubscription>[];

    for (var stream in streams) {
      final subscription = stream.listen(
            (internships) {
          // Add new internships to the collection
          allInternships.addAll(internships);

          // Sort all internships by postedAt in descending order
          // Handle null postedAt values by putting them at the end
          allInternships.sort((a, b) {
            // Handle null cases
            if (a.postedAt == null && b.postedAt == null) return 0;
            if (a.postedAt == null) return 1; // Put null at the end
            if (b.postedAt == null) return -1; // Put null at the end

            // Both are not null, compare normally
            return b.postedAt!.compareTo(a.postedAt!);
          });

          // Emit a copy of the sorted list
          controller.add(List.from(allInternships));
        },
        onError: (error) {
          debugPrint('Error in merged stream: $error');
          // Still emit current list even if there's an error
          controller.add(List.from(allInternships));
        },
        onDone: () {
          // When all streams are done, check if we should close
          final allDone = subscriptions.every((sub) => sub.isPaused);
          if (allDone) {
            Future.delayed(Duration.zero, () => controller.close());
          }
        },
      );

      subscriptions.add(subscription);
    }

    // Clean up subscriptions when controller closes
    controller.onCancel = () {
      for (var subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<List<IndustrialTraining>> getCurrentCompanyInternshipsFuture(
    String companyId,
  ) async {
    try {
      // Get the internships snapshot
      final snapshot = await _firebaseFirestore
          .collection("users")
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .orderBy('postedAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      List<IndustrialTraining> internships = [];

      // Get company data once (outside the loop for better performance)
      final companyDoc = await _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection('companies')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        debugPrint('Company $companyId does not exist');
        return [];
      }

      final company = Company.fromMap(
        companyDoc.data() as Map<String, dynamic>,
      );

      // Process all internships in parallel
      final futures = snapshot.docs.map((doc) async {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Create the IndustrialTraining object
          IndustrialTraining it = IndustrialTraining.fromMap(data, doc.id);
          it.company = company;

          // Get applications count
          it.applicationsCount = await getApplicationsCount(companyId, doc.id);

          return it;
        } catch (e, stackTrace) {
          debugPrint('Error processing internship ${doc.id}: $e');
          debugPrint('Stack Trace: $stackTrace');
          return null;
        }
      }).toList();

      // Wait for all futures and filter out null values
      final results = await Future.wait(futures);
      internships.addAll(results.whereType<IndustrialTraining>());

      return internships;
    } catch (e, stackTrace) {
      debugPrint('Error fetching company internships: $e');
      debugPrint('Stack Trace: $stackTrace');
      return [];
    }
  }

  Future<List<StudentApplication>> getBasicApplicationsForInternshipFuture(
    String companyId,
    String internshipId,
  ) async {
    try {
      // Get applications snapshot
      final snapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internshipId)
          .collection('applications')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No applications found for internship $internshipId');
        return [];
      }

      List<StudentApplication> applications = [];

      // Process all applications
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint("data is ${data.toString()}");

          // Create StudentApplication using fromMap
          final application = StudentApplication.fromMap(
            data,
            doc.id,
            internshipId,
          );

          applications.add(application);
        } catch (e, stackTrace) {
          debugPrint('Error parsing application ${doc.id}: $e');
          debugPrint('Stack Trace: $stackTrace');
          // Continue processing other applications
          continue;
        }
      }

      debugPrint('Successfully loaded ${applications.length} applications');
      return applications;
    } catch (e, stackTrace) {
      debugPrint(
        'Error fetching applications for internship $internshipId: $e',
      );
      debugPrint('Stack Trace: $stackTrace');
      return [];
    }
  }

  Future<List<Student>> getStudentsThatAppliedForCompany(
    String companyId,
  ) async {
    try {
      // Get the company document
      final companyDoc = await _firebaseFirestore
          .collection("users")
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        debugPrint('Company $companyId not found');
        return [];
      }

      final companyData = companyDoc.data() as Map<String, dynamic>;
      final potentialTrainees =
          companyData['potentialtrainee'] as List<dynamic>?;

      if (potentialTrainees == null || potentialTrainees.isEmpty) {
        debugPrint('No potential trainees found for company $companyId');
        return [];
      }

      // Fetch all students in parallel
      final List<Future<Student?>> studentFutures = [];

      for (var studentId in potentialTrainees) {
        if (studentId is String && studentId.isNotEmpty) {
          studentFutures.add(_itcFirebaseLogic.getStudent(studentId));
        }
      }

      if (studentFutures.isEmpty) {
        return [];
      }

      // Wait for all student fetches
      final students = await Future.wait(studentFutures);

      // Filter out null values and return
      return students.whereType<Student>().toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting students for company $companyId: $e');
      debugPrint('Stack Trace: $stackTrace');
      return [];
    }
  }

  Future<int> getApplicationsCount(
    String companyId,
    String internshipId,
  ) async {
    try {
      // Count applications with status 'accept' or 'accepted'
      final snapshot = await _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internshipId)
          .collection('applications')
          .where('applicationStatus', whereIn: ['accept', 'accepted'])
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting applications count: $e');

      // Fallback: Count manually with the same condition
      try {
        final snapshot = await _firebaseFirestore
            .collection("users")
            .doc("companies")
            .collection('companies')
            .doc(companyId)
            .collection('IT')
            .doc(internshipId)
            .collection('applications')
            .where('applicationStatus', whereIn: ['accept', 'accepted'])
            .get();

        return snapshot.docs.length;
      } catch (e2) {
        debugPrint('Error with manual count: $e2');
        return 0;
      }
    }
  }

  Future<void> addApplicationsToInternship({
    required IndustrialTraining internship,
    required List<String> studentIds,
    required Map<String, dynamic> durationDetails,
    required String idCardUrl,
    required String itLetterUrl,
    required List<String> attachedFormUrls,
  }) async {
    final String internshipId = internship.id!;
    final Company? company = await _itcFirebaseLogic.getCompany(
      internship.company.id,
    );

    if (company == null) {
      throw Exception("Company not found for internship ${internship.id}");
    }

    final applicationsRef = _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(company.id)
        .collection('IT')
        .doc(internshipId)
        .collection('applications');

    final batch = _firebaseFirestore.batch();

    for (final uid in studentIds) {
      final student = await ITCFirebaseLogic().getStudent(uid); // fetch student
      if (student == null) continue;

      final application = StudentApplication(
        id: "",
        student: student,
        internship: internship,
        applicationStatus: "pending", // default status
        applicationDate: DateTime.now(),
        durationDetails: durationDetails,
        idCardUrl: idCardUrl,
        itLetterUrl: itLetterUrl,
        attachedFormUrls: attachedFormUrls,
      );

      final now = DateTime.now();
      final formattedDate = DateFormat(
        'yyyyMMdd',
      ).format(now); // Format: 20231225
      final docId = '${student.uid}_$formattedDate';
      final appDocRef = applicationsRef.doc(docId);
      batch.set(appDocRef, application.toMap());
    }

    await batch.commit();
  }

  Future<List<StudentApplication>> getStudentInternshipApplicationsForCompany(
    String companyId,
  ) async {
    final internshipsSnapshot = await _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('internships')
        .get();

    List<StudentApplication> applications = [];

    for (var internshipDoc in internshipsSnapshot.docs) {
      final internshipData = internshipDoc.data();
      final company = await _itcFirebaseLogic.getCompany(
        internshipData['company']['id'],
      );
      if (company == null) continue;

      final internship = IndustrialTraining.fromMap(
        internshipData,
        internshipDoc.id,
      );
      internship.company = company;

      final applicationsSnapshot = await internshipDoc.reference
          .collection('applications')
          .get();

      for (var applicationDoc in applicationsSnapshot.docs) {
        final applicationData = applicationDoc.data();

        final student = Student.fromFirestore(
          applicationData['student'] as Map<String, dynamic>,
          applicationData['student']['uid'],
        );

        final application = StudentApplication.fromMap(
          applicationData,
          internshipDoc.id,
          applicationDoc.id,
        );
        application.internship = internship;
        application.student = student;

        applications.add(application);
      }
    }

    return applications;
  }

  Future<void> updateApplicationStatus({
    required String companyId,
    required String internshipId,
    required String studentId,
    required String status, // 'accepted' or 'rejected'
    required StudentApplication application,
  required bool isAuthority
  }) async {
    status = GeneralMethods.normalizeApplicationStatus(status);
    debugPrint("application id is ${application.id}");
    final appRef = _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('IT')
        .doc(internshipId)
        .collection('applications')
        .doc(application.id);

    await appRef.update({'applicationStatus': status});
    Company? company = await _itcFirebaseLogic.getCompany(
      FirebaseAuth.instance.currentUser!.uid,
    );

    RecentAction action = RecentAction(
      id: "",
      userId: FirebaseAuth.instance.currentUser!.uid,
      userName: company?.name ?? "",
      userEmail: company?.email ?? "",
      userRole: company?.role ?? "",
      actionType: "$status Application",
      entityType: "Application",
      entityId: application.id,
      entityName: application.internship.title,
      description: status,
      timestamp: DateTime.now(),
    );
    // Log audit trail
    if (status.toLowerCase() == 'accepted' || status.toLowerCase()=='accept') {
      await incrementInternshipApplicationCount(companyId, internshipId,isAuthority: isAuthority);
    }
    if(status.toLowerCase() == 'accepted' || status.toLowerCase() == 'rejected') {
      await TraineeService().createTraineeFromApplication(
        isAuthority:isAuthority,
          application: application,
          companyId: companyId,
          companyName: company?.name ?? "",
          fromUpdateStatus: true,
          status: status.toLowerCase());
    }
    await actionLogger.logAction(action, companyId: companyId,isAuthority:isAuthority);
  }

  // In Company_Cloud class - Add this method
  Future<void> updateApplicationStatusByIds({
    required String companyId,
    required String internshipId,
    required String studentId,
    required String applicationId,
    required String status, // 'accepted' or 'rejected'
      required bool isAuthority
  }) async {
    try {
      status = GeneralMethods.normalizeApplicationStatus(status);

      // Get the application reference
      final appRef = _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internshipId)
          .collection('applications')
          .doc(applicationId);
       debugPrint("companyid $companyId internshipid $internshipId applcationId $applicationId");
      // First, get the application document to get the data
      final appDoc = await appRef.get();
      if (!appDoc.exists) {
        throw Exception('Application not found: $applicationId');
      }

      // Update the application status
      await appRef.update({'applicationStatus': status});

      // Get company info for audit log
      Company? company = await _itcFirebaseLogic.getCompany(
        FirebaseAuth.instance.currentUser!.uid,
      );

      // Get internship title for audit log
      final internshipDoc = await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internshipId)
          .get();

      final internshipTitle = internshipDoc.exists
          ? (internshipDoc.data()?['title'] ?? 'Unknown Internship')
          : 'Unknown Internship';

      // Create audit trail
      RecentAction action = RecentAction(
        id: "",
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: company?.name ?? "",
        userEmail: company?.email ?? "",
        userRole: company?.role ?? "",
        actionType: "$status Application",
        entityType: "Application",
        entityId: applicationId,
        entityName: internshipTitle,
        description: status,
        timestamp: DateTime.now(),
      );

      // Log audit trail
      if (status.toLowerCase() == 'accepted') {
        await incrementInternshipApplicationCount(companyId, internshipId,isAuthority: isAuthority);
      }

      await actionLogger.logAction(action, companyId: companyId,isAuthority:isAuthority);

    } catch (e, stackTrace) {
      debugPrint('Error updating application status by IDs: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }


  Future<List<StudentApplication>> studentInternshipApplicationsForCompany(
    String companyId,
  ) async {
    final internshipsSnapshot = await _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('IT')
        .get();

    List<StudentApplication> applications = [];

    for (var internshipDoc in internshipsSnapshot.docs) {
      final internshipData = internshipDoc.data();
      final company = await _itcFirebaseLogic.getCompany(
        internshipData['company']['id'],
      );

      if (company == null) continue;

      final internship = IndustrialTraining.fromMap(
        internshipData,
        internshipDoc.id,
      );
      internship.company = company;

      final applicationsSnapshot = await internshipDoc.reference
          .collection('applications')
          .get();

      for (var applicationDoc in applicationsSnapshot.docs) {
        final appData = applicationDoc.data();
        final student = await _itcFirebaseLogic.getStudent(
          appData['student']['uid'],
        );
        if (student != null) {
          appData['student'] = student.toMap();
        }

        final application = StudentApplication.fromMap(
          appData,
          internshipDoc.id,
          applicationDoc.id,
        );
        application.internship = internship;
        applications.add(application);
      }
    }

    return applications;
  }

  Stream<List<StudentApplication>> studentInternshipApplicationsForCompanyStream(
      String companyId, {
        bool sortAscending = false, // true for oldest first, false for newest first
      }) {
    return _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('IT')
        .snapshots()
        .asyncMap((internshipsSnapshot) async {
      if (internshipsSnapshot.docs.isEmpty) {
        return [];
      }

      // Get all internships first
      final internships = <String, IndustrialTraining>{};
      final List<Future<void>> internshipFutures = [];

      for (var internshipDoc in internshipsSnapshot.docs) {
        internshipFutures.add(
          _processInternship(internshipDoc).then((internship) {
            if (internship != null) {
              internships[internshipDoc.id] = internship;
            }
          }),
        );
      }

      await Future.wait(internshipFutures);

      // Now get applications for all internships
      final List<Future<List<StudentApplication>>> applicationFutures = [];

      for (var internshipDoc in internshipsSnapshot.docs) {
        final internship = internships[internshipDoc.id];
        if (internship != null) {
          applicationFutures.add(
            _getApplicationsForInternship(
              internshipDoc.reference,
              internship,
            ),
          );
        }
      }

      final allApplications = await Future.wait(applicationFutures);
      final combinedApplications = allApplications.expand((apps) => apps).toList();

      // Sort applications
      return _sortApplications(combinedApplications, ascending: sortAscending);
    });
  }

  // New method: Get students with their latest applications
  Stream<List<StudentWithLatestApplication>> streamStudentsWithLatestApplications(
      String companyId, {
        int limit = 100, // Limit total applications fetched
        bool sortByRecent = true,
        bool isAuthority = false,
        List<String>? companyIds,
      }) {
    // Determine which company IDs to use
    final targetCompanyIds = (isAuthority && companyIds != null && companyIds.isNotEmpty)
        ? companyIds
        : [companyId];

    // Create a stream that combines results from all target companies
    return _combineCompanyStreams(targetCompanyIds, limit, sortByRecent);
  }

// Helper method to combine streams from multiple companies
  Stream<List<StudentWithLatestApplication>> _combineCompanyStreams(
      List<String> companyIds,
      int limit,
      bool sortByRecent,
      ) {
    // Create a stream for each company
    final List<Stream<List<StudentWithLatestApplication>>> companyStreams = [];

    for (final companyId in companyIds) {
      companyStreams.add(_createCompanyStream(companyId, limit, sortByRecent));
    }

    // Combine all streams and merge their results
    if (companyStreams.isEmpty) {
      return Stream.value([]);
    }

    if (companyStreams.length == 1) {
      return companyStreams.first;
    }

    // Combine multiple streams with explicit type annotation
    return CombineLatestStream(
      companyStreams,
          (List<dynamic> values) {
        // Cast to the correct type
        final allResults = values.cast<List<StudentWithLatestApplication>>();

        // Merge all results from different companies
        final mergedResults = <StudentWithLatestApplication>[];
        final studentIdMap = <String, StudentWithLatestApplication>{};

        // Process results from all companies
        for (final companyResults in allResults) {
          for (final studentApp in companyResults) {
            final studentId = studentApp.student.uid;

            if (studentIdMap.containsKey(studentId)) {
              // Student already exists, check if this application is more recent
              final existing = studentIdMap[studentId]!;
              final existingDate = existing.lastApplicationDate ?? DateTime(1900);
              final newDate = studentApp.lastApplicationDate ?? DateTime(1900);

              if (newDate.isAfter(existingDate)) {
                // New application is more recent, update
                studentIdMap[studentId] = studentApp.copyWith(
                  totalApplications: existing.totalApplications + studentApp.totalApplications,
                );
              } else {
                // Existing application is more recent, just update total count
                studentIdMap[studentId] = existing.copyWith(
                  totalApplications: existing.totalApplications + studentApp.totalApplications,
                );
              }
            } else {
              // New student, add to map
              studentIdMap[studentId] = studentApp;
            }
          }
        }

        // Convert map to list
        mergedResults.addAll(studentIdMap.values);

        // Sort the merged results
        mergedResults.sort((a, b) {
          if (sortByRecent) {
            final dateA = a.lastApplicationDate ?? DateTime(1900);
            final dateB = b.lastApplicationDate ?? DateTime(1900);
            return dateB.compareTo(dateA); // Newest first
          } else {
            return a.studentName.compareTo(b.studentName); // Alphabetical
          }
        });

        // Apply limit if needed
        return limit > 0 && mergedResults.length > limit
            ? mergedResults.sublist(0, limit)
            : mergedResults;
      },
    );
  }

// Helper method to create stream for a single company
  Stream<List<StudentWithLatestApplication>> _createCompanyStream(
      String companyId,
      int limit,
      bool sortByRecent,
      ) {
    return _firebaseFirestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('IT')
        .snapshots()
        .asyncMap((internshipsSnapshot) async {
      if (internshipsSnapshot.docs.isEmpty) {
        return [];
      }

      // Step 1: Get all internships for this company
      final internships = <String, IndustrialTraining>{};
      final List<Future<void>> internshipFutures = [];

      for (var internshipDoc in internshipsSnapshot.docs) {
        internshipFutures.add(
          _processInternship(internshipDoc).then((internship) {
            if (internship != null) {
              internships[internshipDoc.id] = internship;
            }
          }),
        );
      }

      await Future.wait(internshipFutures);

      // Step 2: Get all applications across all internships
      final List<Future<List<StudentApplication>>> allApplicationFutures = [];

      for (var internshipDoc in internshipsSnapshot.docs) {
        final internship = internships[internshipDoc.id];
        if (internship != null) {
          allApplicationFutures.add(
            _getApplicationsForInternship(
              internshipDoc.reference,
              internship,
            ),
          );
        }
      }

      final allApplicationsNested = await Future.wait(allApplicationFutures);
      final allApplications = allApplicationsNested.expand((apps) => apps).toList();

      // Step 3: Group applications by student ID
      final Map<String, List<StudentApplication>> applicationsByStudent = {};

      for (var application in allApplications) {
        final studentId = application.student.uid;
        if (!applicationsByStudent.containsKey(studentId)) {
          applicationsByStudent[studentId] = [];
        }
        applicationsByStudent[studentId]!.add(application);
      }

      // Step 4: Create StudentWithLatestApplication objects
      final List<StudentWithLatestApplication> result = [];

      for (var entry in applicationsByStudent.entries) {
        final studentApplications = entry.value;

        if (studentApplications.isNotEmpty) {
          // Sort applications by date to get the latest one
          studentApplications.sort((a, b) =>
              b.applicationDate.compareTo(a.applicationDate));

          final latestApplication = studentApplications.first;
          final totalApplications = studentApplications.length;
          final lastApplicationDate = latestApplication.applicationDate;

          result.add(StudentWithLatestApplication(
            student: latestApplication.student,
            latestApplication: latestApplication,
            totalApplications: totalApplications,
            lastApplicationDate: lastApplicationDate,
          ));
        }
      }

      // Step 5: Sort the result for this company
      result.sort((a, b) {
        if (sortByRecent) {
          final dateA = a.lastApplicationDate ?? DateTime(1900);
          final dateB = b.lastApplicationDate ?? DateTime(1900);
          return dateB.compareTo(dateA); // Newest first
        } else {
          return a.studentName.compareTo(b.studentName); // Alphabetical
        }
      });

      // Apply limit for this company's results
      final limitedResult = limit > 0 && result.length > limit
          ? result.sublist(0, limit)
          : result;

      return limitedResult;
    });
  }

// Helper method for processing internship
  Future<IndustrialTraining?> _processInternship(DocumentSnapshot internshipDoc) async {
    try {
      final data = internshipDoc.data() as Map<String, dynamic>;
      return IndustrialTraining.fromMap(data, internshipDoc.id);
    } catch (e) {
      debugPrint('Error processing internship ${internshipDoc.id}: $e');
      return null;
    }
  }


  // Helper method to get applications for a specific internship
  Future<List<StudentApplication>> _getApplicationsForInternship(
      DocumentReference internshipRef,
      IndustrialTraining internship,
      ) async {
    try {
      final applicationsSnapshot = await internshipRef
          .collection('applications')
          .orderBy('applicationDate', descending: true)
          .get();

      final List<StudentApplication> applications = [];

      for (var appDoc in applicationsSnapshot.docs) {
        try {
          final appData = appDoc.data() as Map<String, dynamic>;

          // Get student data from the application
          final studentMap = appData['student'] as Map<String, dynamic>?;
          if (studentMap == null) continue;

          final student = Student.fromMap(studentMap);

          final application = StudentApplication(
            id: appDoc.id,
            student: student,
            internship: internship,
            applicationStatus: appData['applicationStatus'] as String? ?? 'pending',
            applicationDate: _parseDynamicToDateTime(appData['applicationDate']),
            durationDetails: appData['durationDetails'] as Map<String, dynamic>? ?? {},
            idCardUrl: appData['idCardUrl'] as String? ?? '',
            itLetterUrl: appData['itLetterUrl'] as String? ?? '',
            attachedFormUrls: List<String>.from(
              appData['attachedFormUrls'] as List<dynamic>? ?? [],
            ),
          );

          applications.add(application);
        } catch (e) {
          debugPrint('Error parsing application ${appDoc.id}: $e');
        }
      }

      return applications;
    } catch (e) {
      debugPrint('Error getting applications for internship: $e');
      return [];
    }
  }

  DateTime _parseDynamicToDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else if (value is DateTime) {
      return value;
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  }

  // Optional: Get only students with pending applications
  Stream<List<StudentWithLatestApplication>> streamStudentsWithPendingApplications(
      String companyId,
      ) {
    return streamStudentsWithLatestApplications(companyId).map((students) {
      return students.where((student) {
        final status = student.latestApplication?.applicationStatus;
        return status == 'pending' || status == null;
      }).toList();
    });
  }

  // Optional: Get only students with accepted applications
  Stream<List<StudentWithLatestApplication>> streamStudentsWithAcceptedApplications(
      String companyId,
      ) {
    return streamStudentsWithLatestApplications(companyId).map((students) {
      return students.where((student) {
        return student.latestApplication?.isAccepted == true;
      }).toList();
    });
  }



  Stream<List<StudentApplication>> studentInternshipApplicationsForSpecificITStream(
      String companyId,
      String itId,  // Add this parameter for specific IT
          {
        bool sortAscending = false,
      }) {
    debugPrint("specific method is being called");
    return _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('IT')
        .doc(itId)  // Get specific IT document
        .snapshots()
        .asyncMap((internshipSnapshot) async {
      // Check if the specific IT exists
      if (!internshipSnapshot.exists) {
        debugPrint('IT with ID $itId not found for company $companyId');
        return [];
      }

      // Process the single internship
      final internship = await _processInternship(internshipSnapshot);
      if (internship == null) {
        debugPrint('Failed to process internship $itId');
        return [];
      }

      // Get applications for this specific internship
      final applications = await _getApplicationsForInternship(
        internshipSnapshot.reference,
        internship,
      );

      // Sort applications
      return _sortApplications(applications, ascending: sortAscending);
    });
  }
  List<StudentApplication> _sortApplications(
      List<StudentApplication> applications, {
        bool ascending = true,
      }) {
    return applications..sort((a, b) {
      // Handle null dates - put them at the end for ascending, beginning for descending
      if (a.applicationDate == null && b.applicationDate == null) return 0;
      if (a.applicationDate == null) return ascending ? 1 : -1;
      if (b.applicationDate == null) return ascending ? -1 : 1;

      // Compare dates
      final dateComparison = a.applicationDate!.compareTo(b.applicationDate!);

      // Return based on sort order
      return ascending ? dateComparison : -dateComparison;
    });
  }
  Stream<List<StudentApplication>> getBasicApplicationsForInternshipStream(
    String companyId,
    String internshipId,
  ) {
    return _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('IT')
        .doc(internshipId)
        .collection('applications')

        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  debugPrint("data is ${data.toString()}");
                  final application = StudentApplication.fromMap(
                    data,
                    doc.id,
                    internshipId,
                  );

                  // Add internship ID to application if needed
                  //application. = internshipId;

                  return application;
                } catch (e) {
                  debugPrint('Error parsing application ${doc.id}: $e');
                  return null;
                }
              })
              .where((app) => app != null)
              .cast<StudentApplication>()
              .toList();
        })
        .handleError((error) {
          debugPrint('Error in applications stream: $error');
          return [];
        });
  }



  Future<StudentApplication?> _processApplication(
    QueryDocumentSnapshot applicationDoc,
    String internshipId,
    IndustrialTraining internship,
  ) async {
    try {
      final appData = applicationDoc.data() as Map<String, dynamic>?;
      if (appData == null) return null;

      // Get student data
      final student = await _itcFirebaseLogic.getStudent(
        appData['student']['uid'] as String? ?? '',
      );

      if (student == null) return null;

      // Update appData with student information
      final updatedAppData = Map<String, dynamic>.from(appData);
      updatedAppData['student'] = student.toMap();

      final application = StudentApplication.fromMap(
        updatedAppData,
        internshipId,
        applicationDoc.id,
      );
      application.internship = internship;
      return application;
    } catch (e) {
      debugPrint('Error processing application ${applicationDoc.id}: $e');
      return null;
    }
  }

  Future<List<StudentApplication>> getStudentApplicationsWithStatus(
    String studentId,
  ) async {
    final List<StudentApplication> results = [];
    debugPrint("studentId " + studentId);
    // fetch the student once
    final student = await _itcFirebaseLogic.getStudent(studentId);
    if (student == null) return results;

    final companiesSnapshot = await _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .get();

    for (var companyDoc in companiesSnapshot.docs) {
      final internshipsSnapshot = await companyDoc.reference
          .collection('IT')
          .get();

      for (var internshipDoc in internshipsSnapshot.docs) {
        final applicationSnap = await internshipDoc.reference
            .collection('applications')
            .doc(studentId)
            .get();

        if (!applicationSnap.exists) continue;

        final appData = applicationSnap.data() ?? {};
        debugPrint("company is ${appData['internship']['company']}");

        final company = await _itcFirebaseLogic.getCompany(
          appData['internship']['company']['id'],
        );
        if (company == null) continue;

        final internship = IndustrialTraining.fromMap(
          internshipDoc.data(),
          internshipDoc.id,
        );
        internship.company = company;
        StudentApplication application = StudentApplication.fromMap(
          appData,
          internshipDoc.id,
          applicationSnap.id,
        );
        application.internship = internship;
        results.add(application);
      }
    }

    return results;
  }

  Future<void> deleteInternship(IndustrialTraining internship) async {
    final internshipRef = _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(internship.company.id)
        .collection('IT')
        .doc(internship.id);

    // Delete all nested application documents
    final applicationsSnapshot = await internshipRef
        .collection('applications')
        .get();
    final batch = _firebaseFirestore.batch();

    for (var appDoc in applicationsSnapshot.docs) {
      batch.delete(appDoc.reference);
    }

    // Delete the internship document
    batch.delete(internshipRef);

    await batch.commit();
  }

  Future<bool> deleteApplications({
    required String companyId,
    required String internship,
    required String studentId,
    required StudentApplication application,
    required String reason,
  required bool isAuthority
  }) async {
    try {
      // Validate inputs
      debugPrint("application id ${application.id}");
      if (companyId.isEmpty || internship.isEmpty || studentId.isEmpty) {
        print(
          'Invalid parameters: companyId, internship, or studentId is empty',
        );
        return false;
      }

      // Get reference to the internship document
      final internshipRef = _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internship)
          .collection("applications")
          .doc(application.id);

      // Create a batch for atomic operations
      final batch = _firebaseFirestore.batch();

      // Check if the application document exists
      final appDocSnapshot = await internshipRef.get();
      if (!appDocSnapshot.exists) {
        print('Application not found for studentId: $studentId');
        return false;
      }

      batch.delete(internshipRef);
      await batch.commit();

      Company? company = await _itcFirebaseLogic.getCompany(
        FirebaseAuth.instance.currentUser!.uid,
      );

      RecentAction action = RecentAction(
        id: "",
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: company?.name ?? "",
        userEmail: company?.email ?? "",
        userRole: company?.role ?? "",
        actionType: "Deletion",
        entityType: "Application",
        entityId: application.id,
        entityName: application.internship.title,
        description: reason,
        timestamp: DateTime.now(),
      );
      // Log audit trail
      await actionLogger.logAction(action, companyId: companyId,isAuthority: isAuthority);
      _cloudStorage.deleteFile(application.idCardUrl);
      _cloudStorage.deleteFile(application.itLetterUrl);
      //_cloudStorage.deleteFile(application.attachedFormUrls);

      return true;
    } on FirebaseException catch (e) {
      print('Firebase error deleting application: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error deleting application: $e');
      return false;
    }
  }

  Stream<List<Company>> getAllCompanies() {
    return _firebaseFirestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Company company = Company.fromMap(
              doc.data() as Map<String, dynamic>,
            );
            return company;
          }).toList();
        });
  }

  Future<List<Company>> searchCompaniesByName(String nameQuery) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc('companies')
        .collection('companies')
        .get();

    final lowercaseQuery = nameQuery.toLowerCase();

    return snapshot.docs
        .map((doc) => Company.fromMap(doc.data()))
        .where((company) => company.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Add a review for a company
  Future<void> addCompanyReview(CompanyReview review) async {
    final reviewRef = _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(review.companyId)
        .collection('reviews')
        .doc(review.id);
    await reviewRef.set(review.toMap());
  }

  Stream<List<CompanyReview>> getCompanyReviews(String companyId) {
    return _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CompanyReview.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Get average rating for a company
  Future<double> getAverageCompanyRating(String companyId) async {
    final snapshot = await _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(companyId)
        .collection('reviews')
        .get();
    if (snapshot.docs.isEmpty) return 0.0;
    final ratings = snapshot.docs.map((doc) => (doc['rating'] as int)).toList();
    final avg = ratings.reduce((a, b) => a + b) / ratings.length;
    return avg;
  }

  /// 🔥 Get total number of new applications (pending applications)
  Future<int> getTotalNewApplications(String companyId) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );

      // Filter only pending applications
      final newApplications = applications.where((app) {
        return app.applicationStatus.toLowerCase() == 'pending';
      }).toList();

      return newApplications.length;
    } catch (e) {
      debugPrint('Error getting new applications: $e');
      return 0;
    }
  }

  /// 🔥 Get total number of accepted applications
  Future<int> getTotalAcceptedApplications(String companyId) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );

      // Filter only accepted applications
      final acceptedApplications = applications.where((app) {
        return app.applicationStatus.toLowerCase() == 'accepted';
      }).toList();

      return acceptedApplications.length;
    } catch (e, s) {
      debugPrint('Error getting accepted applications: $e');
      debugPrintStack(stackTrace: s);

      return 0;
    }
  }

  /// 🔥 Get total number of rejected applications
  Future<int> getTotalRejectedApplications(String companyId) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );

      // Filter only rejected applications
      final rejectedApplications = applications.where((app) {
        return app.applicationStatus.toLowerCase() == 'rejected';
      }).toList();

      return rejectedApplications.length;
    } catch (e) {
      debugPrint('Error getting rejected applications: $e');
      return 0;
    }
  }

  /// 🔥 Get total number of all applications (regardless of status)
  Future<int> getTotalApplications(String companyId) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );
      return applications.length;
    } catch (e) {
      debugPrint('Error getting total applications: $e');
      return 0;
    }
  }

  /// 🔥 Get accepted applications only
  Future<List<StudentApplication>> getAcceptedApplications(
    String companyId,
  ) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );

      return applications.where((app) {
        return app.applicationStatus.toLowerCase() == 'accepted';
      }).toList();
    } catch (e) {
      debugPrint('Error getting accepted applications list: $e');
      return [];
    }
  }

  /// 🔥 Get pending applications only
  Future<List<StudentApplication>> getPendingApplications(
    String companyId,
  ) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );

      return applications.where((app) {
        return app.applicationStatus.toLowerCase() == 'pending';
      }).toList();
    } catch (e) {
      debugPrint('Error getting pending applications list: $e');
      return [];
    }
  }

  /// 🔥 Get rejected applications only
  Future<List<StudentApplication>> getRejectedApplications(
    String companyId,
  ) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );

      return applications.where((app) {
        return app.applicationStatus.toLowerCase() == 'rejected';
      }).toList();
    } catch (e) {
      debugPrint('Error getting rejected applications list: $e');
      return [];
    }
  }

  /// 🔥 Get applications where duration['startDate'] is today (current students)
  Future<List<StudentApplication>> getCurrentStudents(String companyId) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );
      final today = DateTime.now();

      return applications.where((app) {
        // Check if application is accepted
        if (app.applicationStatus.toLowerCase() != 'accepted') {
          return false;
        }

        // Check if durationDetails has startDate
        if (app.durationDetails == null ||
            app.durationDetails!['startDate'] == null) {
          return false;
        }

        // Parse startDate
        final startDate = app.durationDetails!['startDate'];
        DateTime? startDateTime;

        if (startDate is String) {
          startDateTime = DateTime.tryParse(startDate);
        } else if (startDate is Timestamp) {
          startDateTime = startDate.toDate();
        }

        if (startDateTime == null) {
          return false;
        }

        // Check if startDate is today
        return startDateTime.year == today.year &&
            startDateTime.month == today.month &&
            startDateTime.day == today.day;
      }).toList();
    } catch (e) {
      debugPrint('Error getting current students: $e');
      return [];
    }
  }

  /// 🔥 Get number of current students (applications starting today)
  Future<int> getTotalCurrentStudents(String companyId) async {
    try {
      final currentStudents = await getCurrentStudents(companyId);
      return currentStudents.length;
    } catch (e) {
      debugPrint('Error getting total current students: $e');
      return 0;
    }
  }

  /// 🔥 Get applications where duration['startDate'] is in the past (ongoing students)
  Future<List<StudentApplication>> getOngoingStudents(String companyId) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );
      final today = DateTime.now();

      return applications.where((app) {
        // Check if application is accepted
        if (app.applicationStatus.toLowerCase() != 'accepted') {
          return false;
        }

        // Check if durationDetails has startDate and endDate
        if (app.durationDetails == null ||
            app.durationDetails!['startDate'] == null ||
            app.durationDetails!['endDate'] == null) {
          return false;
        }

        // Parse startDate and endDate
        final startDate = app.durationDetails!['startDate'];
        final endDate = app.durationDetails!['endDate'];

        DateTime? startDateTime;
        DateTime? endDateTime;

        // Parse startDate
        if (startDate is String) {
          startDateTime = DateTime.tryParse(startDate);
        } else if (startDate is Timestamp) {
          startDateTime = startDate.toDate();
        }

        // Parse endDate
        if (endDate is String) {
          endDateTime = DateTime.tryParse(endDate);
        } else if (endDate is Timestamp) {
          endDateTime = endDate.toDate();
        }

        if (startDateTime == null || endDateTime == null) {
          return false;
        }

        // Check if today is between startDate and endDate (ongoing)
        return today.isAfter(startDateTime) && today.isBefore(endDateTime);
      }).toList();
    } catch (e) {
      debugPrint('Error getting ongoing students: $e');
      return [];
    }
  }

  /// 🔥 Get applications where duration['endDate'] is in the past (completed students)
  Future<List<StudentApplication>> getCompletedStudents(
    String companyId,
  ) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );
      final today = DateTime.now();

      return applications.where((app) {
        // Check if application is accepted
        if (app.applicationStatus.toLowerCase() != 'accepted') {
          return false;
        }

        // Check if durationDetails has endDate
        if (app.durationDetails == null ||
            app.durationDetails!['endDate'] == null) {
          return false;
        }

        // Parse endDate
        final endDate = app.durationDetails!['endDate'];
        DateTime? endDateTime;

        if (endDate is String) {
          endDateTime = DateTime.tryParse(endDate);
        } else if (endDate is Timestamp) {
          endDateTime = endDate.toDate();
        }

        if (endDateTime == null) {
          return false;
        }

        // Check if endDate is in the past (completed)
        return today.isAfter(endDateTime);
      }).toList();
    } catch (e) {
      debugPrint('Error getting completed students: $e');
      return [];
    }
  }

  /// 🔥 Get application statistics summary
  Future<Map<String, dynamic>> getApplicationStatistics(
    String companyId,
  ) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );
      final today = DateTime.now();

      int total = applications.length;
      int pending = 0;
      int accepted = 0;
      int rejected = 0;
      int current = 0;
      int ongoing = 0;
      int completed = 0;

      for (var app in applications) {
        final status = app.applicationStatus.toLowerCase();

        // Count by status
        if (status == 'pending') pending++;
        if (status == 'accepted') accepted++;
        if (status == 'rejected') rejected++;

        // For accepted applications, check dates
        if (status == 'accepted' && app.durationDetails != null) {
          final startDate = app.durationDetails!['startDate'];
          final endDate = app.durationDetails!['endDate'];

          DateTime? startDateTime;
          DateTime? endDateTime;

          // Parse startDate
          if (startDate is String) {
            startDateTime = DateTime.tryParse(startDate);
          } else if (startDate is Timestamp) {
            startDateTime = startDate.toDate();
          }

          // Parse endDate
          if (endDate is String) {
            endDateTime = DateTime.tryParse(endDate);
          } else if (endDate is Timestamp) {
            endDateTime = endDate.toDate();
          }

          if (startDateTime != null && endDateTime != null) {
            // Check if starts today
            if (startDateTime.year == today.year &&
                startDateTime.month == today.month &&
                startDateTime.day == today.day) {
              current++;
            }

            // Check if ongoing
            if (today.isAfter(startDateTime) && today.isBefore(endDateTime)) {
              ongoing++;
            }

            // Check if completed
            if (today.isAfter(endDateTime)) {
              completed++;
            }
          }
        }
      }

      return {
        'total': total,
        'pending': pending,
        'accepted': accepted,
        'rejected': rejected,
        'current': current,
        'ongoing': ongoing,
        'completed': completed,
        'acceptanceRate': total > 0
            ? (accepted / total * 100).toStringAsFixed(1)
            : '0.0',
        'rejectionRate': total > 0
            ? (rejected / total * 100).toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      debugPrint('Error getting application statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'rejected': 0,
        'current': 0,
        'ongoing': 0,
        'completed': 0,
        'acceptanceRate': '0.0',
        'rejectionRate': '0.0',
      };
    }
  }

  /// 🔥 Stream applications by status (realtime updates)
  Stream<List<StudentApplication>> streamApplicationsByStatus(
    String companyId,
    String status,
  ) {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      final apps = await studentInternshipApplicationsForCompany(companyId);
      return apps
          .where(
            (app) =>
                app.applicationStatus.toLowerCase() == status.toLowerCase(),
          )
          .toList();
    }).asyncMap((future) => future);
  }

  /// 🔥 Get applications from last X days
  Future<List<StudentApplication>> getRecentApplications(
    String companyId,
    int days,
  ) async {
    try {
      final applications = await studentInternshipApplicationsForCompany(
        companyId,
      );
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      return applications.where((app) {
        return app.applicationDate != null &&
            app.applicationDate!.isAfter(cutoffDate);
      }).toList();
    } catch (e) {
      debugPrint('Error getting recent applications: $e');
      return [];
    }
  }

  Future<void> updateCompanyForm(String companyId, List<String> formUrl) async {
    debugPrint("update company form got called for company: $companyId");

    try {
      final docRef = _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection("companies")
          .doc(companyId);

      // First, check if document exists for debugging
      final docSnapshot = await docRef.get();
      debugPrint("Document exists before update: ${docSnapshot.exists}");

      // Use FieldValue.serverTimestamp() instead of DateTime.now()
      await docRef.set({
        'formUrl': formUrl,
        'updatedAt': FieldValue.serverTimestamp(), // ← FIXED HERE
      }, SetOptions(merge: true));

      // Verify the update
      final updatedDoc = await docRef.get();
      debugPrint("Document after update: ${updatedDoc.data()}");

      debugPrint("Update completed for company $companyId");
    } catch (e) {
      debugPrint("Error updating company form: $e");
      rethrow;
    }
  }

  Future<void> removeCompanyForm(String companyId, String formId) async {
    debugPrint("remove company form got called for company: $companyId, form: $formId");

    try {
      final docRef = _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection("companies")
          .doc(companyId);

      // Get current company data
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        throw Exception("Company document not found with ID: $companyId");
      }

      final currentData = docSnapshot.data() as Map<String, dynamic>? ?? {};
      final currentForms = List<Map<String, dynamic>>.from(currentData['forms'] ?? []);

      // Find and remove the form
      final formToRemove = currentForms.firstWhere(
            (form) => form['formId'] == formId,
        orElse: () => {},
      );

      if (formToRemove.isNotEmpty) {
        await docRef.update({
          'forms': FieldValue.arrayRemove([formToRemove]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("Form removed successfully: $formId");
      } else {
        debugPrint("Form not found: $formId");
      }

    } catch (e) {
      debugPrint("Error removing company form: $e");
      rethrow;
    }
  }

  Future<void> addCompanyForm(String companyId, CompanyForm companyForm) async {
    debugPrint("add company form got called for company: $companyId");

    try {
      final docRef = _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection("companies")
          .doc(companyId);

      // Check if document exists
      final docSnapshot = await docRef.get();
      debugPrint("Document exists: ${docSnapshot.exists}");

      if (!docSnapshot.exists) {
        throw Exception("Company document not found with ID: $companyId");
      }

      // Add form to forms array using arrayUnion
      await docRef.update({
        'forms': FieldValue.arrayUnion([companyForm.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("Form added successfully for company $companyId");

    } catch (e) {
      debugPrint("Error adding company form: $e");
      rethrow;
    }
  }

  Future<List<CompanyForm>> getCompanyForms(String companyId) async {
    debugPrint("getCompanyForms called for company: $companyId");

    try {
      final docRef = _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection("companies")
          .doc(companyId);

      // Get the company document
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint("Company document not found with ID: $companyId");
        return [];
      }

      final data = docSnapshot.data() as Map<String, dynamic>? ?? {};
      final formsData = data['forms'] as List<dynamic>? ?? [];

      debugPrint("Found ${formsData.length} forms for company $companyId");

      // Convert each form data to CompanyForm object
      final List<CompanyForm> forms = [];

      for (final formData in formsData) {
        try {
          if (formData is Map<String, dynamic>) {
            final companyForm = CompanyForm.fromMap(formData);
            forms.add(companyForm);
          }
        } catch (e) {
          debugPrint("Error parsing form data: $e");
          debugPrint("Form data: $formData");
        }
      }

      // Sort by upload date (newest first)
      forms.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      debugPrint("Successfully parsed ${forms.length} forms");
      return forms;

    } catch (e) {
      debugPrint("Error getting company forms: $e");
      rethrow;
    }
  }
  Future<void> updateCompanyFormModel(String companyId, CompanyForm companyForm) async {
    debugPrint("update company form got called for company: $companyId");
    debugPrint("Form details - ID: ${companyForm.formId}, Department: ${companyForm.departmentName}");

    try {
      final docRef = _firebaseFirestore
          .collection("users")
          .doc("companies")
          .collection("companies")
          .doc(companyId);

      // First, get the current company data to update forms array
      final docSnapshot = await docRef.get();
      debugPrint("Document exists before update: ${docSnapshot.exists}");

      if (!docSnapshot.exists) {
        throw Exception("Company document not found with ID: $companyId");
      }

      // Get current forms array
      final currentData = docSnapshot.data() as Map<String, dynamic>? ?? {};
      final currentForms = List<Map<String, dynamic>>.from(currentData['forms'] ?? []);

      // Check if form already exists
      final existingFormIndex = currentForms.indexWhere(
              (form) => form['formId'] == companyForm.formId
      );

      if (existingFormIndex != -1) {
        // Update existing form
        currentForms[existingFormIndex] = companyForm.toMap();
        debugPrint("Updating existing form at index $existingFormIndex");
      } else {
        // Add new form
        currentForms.add(companyForm.toMap());
        debugPrint("Adding new form to array");
      }

      // Update the document
      await docRef.update({
        'forms': currentForms,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Verify the update
      final updatedDoc = await docRef.get();
      final updatedForms = List<Map<String, dynamic>>.from(
          updatedDoc.data()?['forms'] ?? []
      );

      debugPrint("Total forms after update: ${updatedForms.length}");
      debugPrint("Latest form: ${updatedForms.last}");

      debugPrint("Update completed for company $companyId");

    } catch (e) {
      debugPrint("Error updating company form: $e");
      rethrow;
    }
  }

  // In your ITCFirebaseLogic class
  Future<void> updateCompany(Company company) async {
    try {
      await FirebaseFirestore.instance
           .collection('users')
           .doc('companies')
          .collection('companies')
          .doc(company.id)
          .update(company.toMap());
    } catch (e) {
      throw Exception('Failed to update company: $e');
    }
  }


  Future<void> sendNotificationToCompany(CompanyNotification notification) async {
    try {
      // Generate a unique ID for the notification
      final notificationId = _firebaseFirestore.collection('notifications').doc().id;

      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(notification.companyId)
          .collection('notifications')
          .doc(notificationId)
          .set(notification.copyWith(id: notificationId).toFirestore());

      debugPrint('✅ Notification sent to company ${notification.companyId}: ${notification.title}');

      // Update company's unread count
      await _incrementUnreadCount(notification.companyId);

    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      rethrow;
    }
  }

  // 2. GET COMPANY NOTIFICATIONS STREAM
  Stream<List<CompanyNotification>> getCompanyNotificationsStream(String companyId) {
    try {
      return _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return CompanyNotification.fromFirestore(doc, null);
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting notifications stream: $e');
      return Stream.value([]);
    }
  }

  // 3. GET UNREAD NOTIFICATIONS COUNT STREAM
  Stream<int> getUnreadNotificationsCountStream(String companyId) {
    try {
      return _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .snapshots()
          .map((snapshot) {
        final data = snapshot.data();
        return data?['unreadNotifications'] ?? 0;
      });
    } catch (e) {
      debugPrint('❌ Error getting unread count stream: $e');
      return Stream.value(0);
    }
  }

  // 4. MARK NOTIFICATION AS READ
  Future<void> markNotificationAsRead(String companyId, String notificationId) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      // Decrement unread count
      await _decrementUnreadCount(companyId);

      debugPrint('✅ Notification $notificationId marked as read');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  // 5. MARK ALL NOTIFICATIONS AS READ
  Future<void> markAllNotificationsAsRead(String companyId) async {
    try {
      final notifications = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) return;

      final batch = _firebaseFirestore.batch();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Reset unread count to 0
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .update({
        'unreadNotifications': 0,
      });

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // 6. MARK NOTIFICATION AS UNREAD
  Future<void> markNotificationAsUnread(String companyId, String notificationId) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': false,
        'readAt': FieldValue.delete(),
      });

      // Increment unread count
      await _incrementUnreadCount(companyId);

      debugPrint('✅ Notification $notificationId marked as unread');
    } catch (e) {
      debugPrint('❌ Error marking notification as unread: $e');
      rethrow;
    }
  }

  // 7. DELETE NOTIFICATION
  Future<void> deleteNotification(String companyId, String notificationId) async {
    try {
      // Check if notification was unread to adjust count
      final doc = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .doc(notificationId)
          .get();

      final wasUnread = doc.data()?['isRead'] == false;

      // Delete the notification
      await doc.reference.delete();

      // Decrement count if it was unread
      if (wasUnread) {
        await _decrementUnreadCount(companyId);
      }

      debugPrint('✅ Notification $notificationId deleted');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      rethrow;
    }
  }

  // 8. DELETE ALL READ NOTIFICATIONS
  Future<void> deleteAllReadNotifications(String companyId) async {
    try {
      final readNotifications = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isRead', isEqualTo: true)
          .get();

      if (readNotifications.docs.isEmpty) return;

      final batch = _firebaseFirestore.batch();

      for (final doc in readNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('✅ All read notifications deleted');
    } catch (e) {
      debugPrint('❌ Error deleting read notifications: $e');
      rethrow;
    }
  }

  // 9. TOGGLE NOTIFICATION IMPORTANCE
  Future<void> toggleNotificationImportant(
      String companyId,
      String notificationId,
      bool isImportant,
      ) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isImportant': isImportant,
      });

      debugPrint('✅ Notification $notificationId importance toggled to $isImportant');
    } catch (e) {
      debugPrint('❌ Error toggling notification importance: $e');
      rethrow;
    }
  }

  // 10. GET NOTIFICATION BY ID
  Future<CompanyNotification?> getNotificationById(
      String companyId,
      String notificationId,
      ) async {
    try {
      final doc = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (!doc.exists) return null;

      return CompanyNotification.fromFirestore(doc, null);
    } catch (e) {
      debugPrint('❌ Error getting notification by ID: $e');
      return null;
    }
  }

  // 11. GET NOTIFICATIONS BY TYPE
  Stream<List<CompanyNotification>> getNotificationsByType(
      String companyId,
      NotificationType type,
      ) {
    try {
      final typeString = _notificationTypeToString(type);

      return _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('type', isEqualTo: typeString)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return CompanyNotification.fromFirestore(doc, null);
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting notifications by type: $e');
      return Stream.value([]);
    }
  }

  // 12. GET UNREAD NOTIFICATIONS
  Stream<List<CompanyNotification>> getUnreadNotifications(String companyId) {
    try {
      return _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return CompanyNotification.fromFirestore(doc, null);
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting unread notifications: $e');
      return Stream.value([]);
    }
  }

  // 13. GET IMPORTANT NOTIFICATIONS
  Stream<List<CompanyNotification>> getImportantNotifications(String companyId) {
    try {
      return _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isImportant', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return CompanyNotification.fromFirestore(doc, null);
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting important notifications: $e');
      return Stream.value([]);
    }
  }

  // 14. GET NOTIFICATIONS WITH PAGINATION
  Future<List<CompanyNotification>> getNotificationsWithPagination(
      String companyId, {
        int limit = 20,
        DocumentSnapshot<Map<String, dynamic>>? lastDocument,
      }) async {
    try {
      Query<Map<String, dynamic>> query = _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return CompanyNotification.fromFirestore(doc, null);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting paginated notifications: $e');
      return [];
    }
  }

  // 15. GET NOTIFICATION STATISTICS
  Future<Map<String, dynamic>> getNotificationStats(String companyId) async {
    try {
      final totalQuery = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .count()
          .get();

      final unreadQuery = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      final importantQuery = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isImportant', isEqualTo: true)
          .count()
          .get();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todayQuery = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .count()
          .get();

      return {
        'total': totalQuery.count,
        'unread': unreadQuery.count,
        'important': importantQuery.count,
        'today': todayQuery.count,
      };
    } catch (e) {
      debugPrint('❌ Error getting notification stats: $e');
      return {
        'total': 0,
        'unread': 0,
        'important': 0,
        'today': 0,
      };
    }
  }

  // 16. UPDATE NOTIFICATION SETTINGS
  Future<void> updateNotificationSettings(
      String companyId,
      Map<String, dynamic> settings,
      ) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .update({
        'notificationSettings': settings,
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification settings updated for company $companyId');
    } catch (e) {
      debugPrint('❌ Error updating notification settings: $e');
      rethrow;
    }
  }

  // 17. GET NOTIFICATION SETTINGS
  Future<Map<String, dynamic>> getNotificationSettings(String companyId) async {
    try {
      final doc = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .get();

      final data = doc.data();
      final settings = data?['notificationSettings'] as Map<String, dynamic>?;

      // Default settings if none exist
      return settings ?? {
        'pushEnabled': true,
        'emailEnabled': false,
        'soundEnabled': true,
        'vibrateEnabled': true,
        'newApplications': true,
        'applicationUpdates': true,
        'studentMessages': true,
        'systemAlerts': true,
        'paymentNotifications': true,
        'reminders': false,
        'lowSlotsAlert': true,
        'dailySummary': false,
      };
    } catch (e) {
      debugPrint('❌ Error getting notification settings: $e');
      return {};
    }
  }

  // 18. SEND BULK NOTIFICATIONS (For announcements)
  Future<void> sendBulkNotifications(
      List<String> companyIds,
      CompanyNotification notification,
      ) async {
    try {
      final batch = _firebaseFirestore.batch();

      for (final companyId in companyIds) {
        final notificationId = _firebaseFirestore.collection('notifications').doc().id;
        final notificationRef = _firebaseFirestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(companyId)
            .collection('notifications')
            .doc(notificationId);

        final companyNotification = notification.copyWith(
          id: notificationId,
          companyId: companyId,
        );

        batch.set(notificationRef, companyNotification.toFirestore());

        // Update unread count for each company
        final companyRef = _firebaseFirestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(companyId);

        batch.update(companyRef, {
          'unreadNotifications': FieldValue.increment(1),
        });
      }

      await batch.commit();
      debugPrint('✅ Bulk notifications sent to ${companyIds.length} companies');
    } catch (e) {
      debugPrint('❌ Error sending bulk notifications: $e');
      rethrow;
    }
  }

  // 19. CHECK FOR UNREAD NOTIFICATIONS
  Future<bool> hasUnreadNotifications(String companyId) async {
    try {
      final snapshot = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking for unread notifications: $e');
      return false;
    }
  }

  // 20. GET RECENT NOTIFICATIONS (Last 7 days)
  Stream<List<CompanyNotification>> getRecentNotifications(String companyId) {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      return _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('notifications')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return CompanyNotification.fromFirestore(doc, null);
        }).toList();
      });
    } catch (e) {
      debugPrint('❌ Error getting recent notifications: $e');
      return Stream.value([]);
    }
  }

  // =============== HELPER METHODS ===============

  // Increment unread count
  Future<void> _incrementUnreadCount(String companyId) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .update({
        'unreadNotifications': FieldValue.increment(1),
        'lastNotificationAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error incrementing unread count: $e');
    }
  }

  // Decrement unread count
  Future<void> _decrementUnreadCount(String companyId) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .update({
        'unreadNotifications': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('❌ Error decrementing unread count: $e');
    }
  }

  // Convert NotificationType to string
  String _notificationTypeToString(NotificationType type) {
    switch (type) {
      case NotificationType.newApplication:
        return 'new_application';
      case NotificationType.applicationUpdate:
        return 'application_update';
      case NotificationType.studentMessage:
        return 'student_message';
      case NotificationType.studentDocument:
        return 'student_document';
      case NotificationType.systemAlert:
        return 'system_alert';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.reminder:
        return 'reminder';
      case NotificationType.report:
        return 'report';
      case NotificationType.announcement:
        return 'announcement';
      case NotificationType.internshipClosed:
        return 'internship_closed';
      case NotificationType.internshipCreated:
        return 'internship_created';
      case NotificationType.lowSlots:
        return 'low_slots';
      case NotificationType.verification:
        return 'verification';
    }
  }

  // =============== SPECIFIC NOTIFICATION CREATORS ===============

  // Send new application notification
  Future<void> sendNewApplicationNotification({
    required String companyId,
    required String internshipId,
    required String internshipTitle,
    required String studentId,
    required String studentName,
    required String applicationId,
  }) async {
    final notification = CompanyNotification.newApplication(
      companyId: companyId,
      internshipId: internshipId,
      internshipTitle: internshipTitle,
      studentId: studentId,
      studentName: studentName,
      applicationId: applicationId,
    );

    await sendNotificationToCompany(notification);
  }

  // Send application status update notification
  Future<void> sendApplicationUpdateNotification({
    required String companyId,
    required String applicationId,
    required String studentName,
    required String internshipTitle,
    required String oldStatus,
    required String newStatus,
  }) async {
    final notification = CompanyNotification.applicationUpdate(
      companyId: companyId,
      applicationId: applicationId,
      studentName: studentName,
      internshipTitle: internshipTitle,
      oldStatus: oldStatus,
      newStatus: newStatus,
    );

    await sendNotificationToCompany(notification);
  }

  // Send student message notification
  Future<void> sendStudentMessageNotification({
    required String companyId,
    required String studentId,
    required String studentName,
    required String messagePreview,
    required String chatId,
  }) async {
    final notification = CompanyNotification.studentMessage(
      companyId: companyId,
      studentId: studentId,
      studentName: studentName,
      messagePreview: messagePreview,
      chatId: chatId,
    );

    await sendNotificationToCompany(notification);
  }

  // Send low slots alert
  Future<void> sendLowSlotsNotification({
    required String companyId,
    required int remainingSlots,
    required int threshold,
  }) async {
    final notification = CompanyNotification.lowSlots(
      companyId: companyId,
      remainingSlots: remainingSlots,
      threshold: threshold,
    );

    await sendNotificationToCompany(notification);
  }

  // Send payment notification
  Future<void> sendPaymentNotification({
    required String companyId,
    required String paymentId,
    required String amount,
    required String status,
    required String description,
  }) async {
    final notification = CompanyNotification.payment(
      companyId: companyId,
      paymentId: paymentId,
      amount: amount,
      status: status,
      description: description,
    );

    await sendNotificationToCompany(notification);
  }

  // Send reminder notification
  Future<void> sendReminderNotification({
    required String companyId,
    required String reminderType,
    required String message,
    required DateTime dueDate,
    required List<String> relatedIds,
  }) async {
    final notification = CompanyNotification.reminder(
      companyId: companyId,
      reminderType: reminderType,
      message: message,
      dueDate: dueDate,
      relatedIds: relatedIds,
    );

    await sendNotificationToCompany(notification);
  }

  // Send internship closed notification
  Future<void> sendInternshipClosedNotification({
    required String companyId,
    required String internshipId,
    required String internshipTitle,
    required int totalApplications,
  }) async {
    final notification = CompanyNotification.internshipClosed(
      companyId: companyId,
      internshipId: internshipId,
      internshipTitle: internshipTitle,
      totalApplications: totalApplications,
    );

    await sendNotificationToCompany(notification);
  }

// Add this method to your TraineeService class
  Future<StudentApplication?> getApplicationById(
      String companyId,
      String internshipId,
      String applicationId
      ) async {
    try {
      debugPrint('Fetching application by ID: $applicationId');

      // Get the application document from Firestore
      final doc = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .doc(internshipId)
          .collection('applications')
          .doc(applicationId)
          .get();
    debugPrint("companyId $companyId internshipId $internshipId applicationId $applicationId");
      if (!doc.exists) {
        debugPrint('Application not found: $applicationId');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      debugPrint("Application data: ${data.toString()}");

      // Use your existing StudentApplication.fromMap method
      final application = StudentApplication.fromMap(
        data,
        doc.id,
        internshipId,
      );

      debugPrint('Successfully loaded application: ${application.id}');
      return application;

    } catch (e, stackTrace) {
      debugPrint('Error getting application by ID: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

// Alternative version that searches across all internships
  Future<StudentApplication?> getApplicationByIdAcrossInternships(
      String companyId,
      String applicationId,
      ) async {
    try {
      debugPrint('Searching for application: $applicationId across all internships');

      // First, get all internships for the company
      final internshipsSnapshot = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .get();

      if (internshipsSnapshot.docs.isEmpty) {
        debugPrint('No internships found for company: $companyId');
        return null;
      }

      // Search each internship's applications collection
      for (final internshipDoc in internshipsSnapshot.docs) {
        final internshipId = internshipDoc.id;

        try {
          final appDoc = await _firebaseFirestore
              .collection('users')
              .doc('companies')
              .collection('companies')
              .doc(companyId)
              .collection('IT')
              .doc(internshipId)
              .collection('applications')
              .doc(applicationId)
              .get();

          if (appDoc.exists) {
            debugPrint('Found application in internship: $internshipId');
            final data = appDoc.data() as Map<String, dynamic>;

            return StudentApplication.fromMap(
              data,
              appDoc.id,
              internshipId,
            );
          }
        } catch (e) {
          debugPrint('Error checking internship $internshipId: $e');
          continue;
        }
      }

      debugPrint('Application $applicationId not found in any internship');
      return null;

    } catch (e, stackTrace) {
      debugPrint('Error getting application across internships: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<StudentApplication>> getAllApplicationsForStudent(
      String companyId,
      String studentUid, {
        bool isAuthority = false,
        List<String>? companiesIds,
      }) async {
    try {
      debugPrint('🔍 Searching for all applications by student: $studentUid');

      // Determine which company IDs to use
      final List<String> targetCompanyIds = (isAuthority && companiesIds != null && companiesIds.isNotEmpty)
          ? companiesIds
          : [companyId];

      debugPrint('🏢 Searching in ${targetCompanyIds.length} company(s): ${targetCompanyIds.join(', ')}');

      final List<StudentApplication> studentApplications = [];

      // Process each company ID
      for (final currentCompanyId in targetCompanyIds) {
        debugPrint('  Checking company: $currentCompanyId');

        // First, get all internships for the current company
        final internshipsSnapshot = await _firebaseFirestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(currentCompanyId)
            .collection('IT')
            .get();

        if (internshipsSnapshot.docs.isEmpty) {
          debugPrint('  📭 No internships found for company: $currentCompanyId');
          continue;
        }

        debugPrint('  📂 Found ${internshipsSnapshot.docs.length} internship(s) in company: $currentCompanyId');

        // Iterate through each internship
        for (final internshipDoc in internshipsSnapshot.docs) {
          final internshipId = internshipDoc.id;
          debugPrint('    Checking internship: $internshipId');

          try {
            // Query applications where document ID starts with studentUid
            final applicationsQuery = await _firebaseFirestore
                .collection('users')
                .doc('companies')
                .collection('companies')
                .doc(currentCompanyId)
                .collection('IT')
                .doc(internshipId)
                .collection('applications')
                .where(FieldPath.documentId, isGreaterThanOrEqualTo: studentUid)
                .where(FieldPath.documentId, isLessThan: studentUid + '\uf8ff')
                .get();

            if (applicationsQuery.docs.isNotEmpty) {
              debugPrint('      📄 Found ${applicationsQuery.docs.length} application(s) in this internship');

              for (final appDoc in applicationsQuery.docs) {
                // Double-check that the document ID starts with studentUid
                if (appDoc.id.startsWith(studentUid)) {
                  try {
                    final data = appDoc.data() as Map<String, dynamic>;

                    final application = StudentApplication.fromMap(
                      data,
                      internshipId,
                      appDoc.id,
                    );

                    // Add internship data to the application if needed
                    final internshipData = internshipDoc.data() as Map<String, dynamic>;
                    application.internship = IndustrialTraining.fromMap(
                        internshipData, internshipDoc.id);

                    // Get student details
                    Student? student = await _itcFirebaseLogic.getStudent(application.student.uid);
                    if (student != null) {
                      application.student = student;
                    }

                    studentApplications.add(application);
                    debugPrint('      Added application: ${appDoc.id} from company: $currentCompanyId');
                  } catch (e) {
                    debugPrint('Error parsing application ${appDoc.id}: $e');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error querying applications for internship $internshipId: $e');
            continue;
          }
        }
      }

      debugPrint('Total applications found for student $studentUid: ${studentApplications.length}');

      // Optional: Sort by application date or other criteria
      studentApplications.sort((a, b) {
        final dateA = a.applicationDate ?? DateTime(0);
        final dateB = b.applicationDate ?? DateTime(0);
        return dateB.compareTo(dateA); // Newest first
      });

      return studentApplications;

    } catch (e, stackTrace) {
      debugPrint('Error getting all applications for student: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

// Method to get application by student and company (useful for trainee records)
  Future<StudentApplication?> getApplicationByStudentAndCompany(
      String studentId,
      String companyId,
      ) async {
    try {
      debugPrint('Getting application for student: $studentId at company: $companyId');

      // Get all internships for the company
      final internshipsSnapshot = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .get();

      if (internshipsSnapshot.docs.isEmpty) return null;

      // Search each internship for the student's application
      for (final internshipDoc in internshipsSnapshot.docs) {
        final internshipId = internshipDoc.id;

        final applicationsSnapshot = await _firebaseFirestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(companyId)
            .collection('IT')
            .doc(internshipId)
            .collection('applications')
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();

        if (applicationsSnapshot.docs.isNotEmpty) {
          final appDoc = applicationsSnapshot.docs.first;
          final data = appDoc.data() as Map<String, dynamic>;

          debugPrint('Found application for student in internship: $internshipId');
          return StudentApplication.fromMap(
            data,
            appDoc.id,
            internshipId,
          );
        }
      }

      debugPrint('No application found for student: $studentId');
      return null;

    } catch (e, stackTrace) {
      debugPrint('Error getting application by student and company: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

// Method to get the most recent application for a student at a company
  Future<StudentApplication?> getLatestApplicationByStudentAndCompany(
      String studentId,
      String companyId,
      ) async {
    try {
      debugPrint('Getting latest application for student: $studentId');

      final allApplications = <StudentApplication>[];

      // Get all internships for the company
      final internshipsSnapshot = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .get();

      // Collect all applications from all internships
      for (final internshipDoc in internshipsSnapshot.docs) {
        final internshipId = internshipDoc.id;

        final applicationsSnapshot = await _firebaseFirestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(companyId)
            .collection('IT')
            .doc(internshipId)
            .collection('applications')
            .where('studentId', isEqualTo: studentId)
            .get();

        for (final appDoc in applicationsSnapshot.docs) {
          try {
            final data = appDoc.data() as Map<String, dynamic>;
            final application = StudentApplication.fromMap(
              data,
              appDoc.id,
              internshipId,
            );
            allApplications.add(application);
          } catch (e) {
            debugPrint('Error parsing application ${appDoc.id}: $e');
            continue;
          }
        }
      }

      if (allApplications.isEmpty) {
        debugPrint('No applications found for student: $studentId');
        return null;
      }

      // Sort by application date (most recent first)
      allApplications.sort((a, b) => b.applicationDate.compareTo(a.applicationDate));

      debugPrint('Found ${allApplications.length} applications, returning most recent');
      return allApplications.first;

    } catch (e, stackTrace) {
      debugPrint('Error getting latest application: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

// Batch version to get multiple applications by IDs
  Future<Map<String, StudentApplication?>> getApplicationsByIds({
    required String companyId,
    required List<String> applicationIds,
  }) async {
    try {
      debugPrint('Getting ${applicationIds.length} applications by IDs');

      final results = <String, StudentApplication?>{};

      // Get all internships for the company
      final internshipsSnapshot = await _firebaseFirestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .collection('IT')
          .get();

      // Create a map to track which applications we've found
      final remainingIds = Set<String>.from(applicationIds);

      // Search each internship
      for (final internshipDoc in internshipsSnapshot.docs) {
        if (remainingIds.isEmpty) break;

        final internshipId = internshipDoc.id;

        // Batch get applications for this internship
        final applicationsSnapshot = await _firebaseFirestore
            .collection('users')
            .doc('companies')
            .collection('companies')
            .doc(companyId)
            .collection('IT')
            .doc(internshipId)
            .collection('applications')
            .where(FieldPath.documentId, whereIn: remainingIds.toList())
            .get();

        for (final appDoc in applicationsSnapshot.docs) {
          try {
            final data = appDoc.data() as Map<String, dynamic>;
            final application = StudentApplication.fromMap(
              data,
              appDoc.id,
              internshipId,
            );
            results[appDoc.id] = application;
            remainingIds.remove(appDoc.id);
          } catch (e) {
            debugPrint('Error parsing application ${appDoc.id}: $e');
            results[appDoc.id] = null;
            remainingIds.remove(appDoc.id);
          }
        }
      }

      // Mark any not found applications as null
      for (final id in remainingIds) {
        results[id] = null;
      }

      debugPrint('Found ${results.length - remainingIds.length} out of ${applicationIds.length} applications');
      return results;

    } catch (e, stackTrace) {
      debugPrint('Error getting applications by IDs: $e');
      debugPrint('Stack trace: $stackTrace');
      // Return null for all IDs on error
      return {for (var id in applicationIds) id: null};
    }
  }
}
