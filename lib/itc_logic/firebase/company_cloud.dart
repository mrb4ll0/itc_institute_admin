import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/firebase_cloud_storage/firebase_cloud.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/firebase/ActionLogger.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart';

import '../../model/RecentActions.dart';
import '../../model/company.dart';
import '../../model/internship_model.dart';
import '../../model/review.dart';
import '../../model/student.dart';
import '../../model/studentApplication.dart';
import 'general_cloud.dart';

class Company_Cloud {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  String usersCollection = "users";
  final ITCFirebaseLogic _itcFirebaseLogic = ITCFirebaseLogic();
  final ActionLogger actionLogger = ActionLogger();
  final FirebaseUploader _cloudStorage = FirebaseUploader();
  final FireStoreNotification fireStoreNotification = FireStoreNotification();

  Future<void> postInternship(IndustrialTraining internship) async {
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
      );
    } catch (e, s) {
      debugPrint(s.toString());
    }
  }

  // In your Company_Cloud class, modify the stream method

  Future<void> updateInternship(IndustrialTraining internship) async {
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

        await actionLogger.logAction(recentAction, companyId: companyId);
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
  ) {
    try {
      return _firebaseFirestore
          .collection("users")
          .doc('companies')
          .collection('companies')
          .doc(companyId) // Current user's company ID
          .collection('IT')
          .orderBy('postedAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            List<IndustrialTraining> internships = [];
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;

                // Get current company data
                final companyDoc = await _firebaseFirestore
                    .collection("users")
                    .doc("companies")
                    .collection('companies')
                    .doc(companyId)
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
                    it.company.id,
                    doc.id,
                  );
                  internships.add(it);
                }
              } catch (e, stackTrace) {
                debugPrint('Error processing internship ${doc.id}: $e');
                continue;
              }
            }
            return internships;
          })
          .handleError((error, stackTrace) {
            debugPrint('Firestore Stream Error: $error');
            debugPrint('Stack Trace: $stackTrace');
            return <IndustrialTraining>[];
          });
    } catch (e, stackTrace) {
      debugPrint('Stream Creation Error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return Stream.value(<IndustrialTraining>[]);
    }
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
  }) async {
    status = GeneralMethods.normalizeApplicationStatus(status);
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
    if (status.toLowerCase() == 'accepted') {
      await incrementInternshipApplicationCount(companyId, internshipId);
    }
    await actionLogger.logAction(action, companyId: companyId);
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

  Stream<List<StudentApplication>>
  studentInternshipApplicationsForCompanyStream(String companyId) {
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
          // for (List<StudentApplication> appList in allApplications) {
          //   for (StudentApplication app in appList) {
          //     // Process each application here
          //
          //   }
          // }
          return allApplications.expand((apps) => apps).toList();
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

  Future<IndustrialTraining?> _processInternship(
    DocumentSnapshot internshipDoc,
  ) async {
    try {
      final internshipData = internshipDoc.data() as Map<String, dynamic>?;
      if (internshipData == null) return null;

      final company = await _itcFirebaseLogic.getCompany(
        internshipData['company']['id'] as String? ?? '',
      );

      if (company == null) return null;

      final internship = IndustrialTraining.fromMap(
        internshipData,
        internshipDoc.id,
      );
      internship.company = company;
      return internship;
    } catch (e) {
      debugPrint('Error processing internship: $e');
      return null;
    }
  }

  Future<List<StudentApplication>> _getApplicationsForInternship(
    DocumentReference internshipRef,
    IndustrialTraining internship,
  ) async {
    try {
      final applicationsSnapshot = await internshipRef
          .collection('applications')
          .get();

      final List<Future<StudentApplication?>> applicationFutures = [];

      for (var applicationDoc in applicationsSnapshot.docs) {
        StudentApplication? app = await _processApplication(
          applicationDoc,
          internshipRef.id,
          internship,
        );

        applicationFutures.add(
          _processApplication(applicationDoc, internshipRef.id, internship),
        );
      }

      final applications = await Future.wait(applicationFutures);
      return applications.whereType<StudentApplication>().toList();
    } catch (e) {
      debugPrint(
        'Error getting applications for internship ${internship.id}: $e',
      );
      return [];
    }
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
      await actionLogger.logAction(action, companyId: companyId);
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
}
