import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import '../model/admin.dart';
import '../model/application.dart';
import '../model/approval.dart';
import '../model/company.dart';
import '../model/internship_model.dart';
import '../model/report.dart';
import '../model/student.dart';

class AdminCloud {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 String globalUserId = "";
  AdminCloud(String userId)
  {
    globalUserId = userId;
    itcFirebaseLogic= ITCFirebaseLogic(globalUserId);
  }
  // ─── USERS ────────────────────────────────────────────────────────────────

  Future<List<Student>> getAllStudents({Company? company}) async {
    try {
      if (company == null) {
        debugPrint("No company provided, cannot fetch potential trainees");
        return [];
      }

      debugPrint("Processing company: ${company.id}");

      // Check if this is an authority company
      if (_isAuthorityCompany(company)) {
        return await _getPotentialTraineesFromAuthorityCompany(company);
      } else {
        return await _getPotentialTraineesFromSingleCompany(company);
      }
    } catch (e, s) {
      debugPrint('Error getting potential trainees: $e');
      debugPrintStack(stackTrace: s);
      return [];
    }
  }

  bool _isAuthorityCompany(Company company) {
    return company.originalAuthority?.linkedCompanies != null &&
        company.originalAuthority!.linkedCompanies!.isNotEmpty;
  }

  Future<List<Student>> _getPotentialTraineesFromAuthorityCompany(Company company) async {
    debugPrint("Authority company detected: ${company.id}");

    // Get all student IDs from linked companies
    final studentIds = await _collectPotentialTraineeIdsFromLinkedCompanies(company);

    if (studentIds.isEmpty) {
      debugPrint("No potential trainees found in linked companies");
      return [];
    }

    debugPrint("Fetching ${studentIds.length} potential trainees from linked companies");
    return await _fetchStudentsByIds(studentIds);
  }

  Future<List<Student>> _getPotentialTraineesFromSingleCompany(Company company) async {
    debugPrint("Fetching potential trainees for single company: ${company.id}");

    // Check if company has potential trainees
    if (company.potentialtrainee == null || company.potentialtrainee!.isEmpty) {
      debugPrint("No potential trainees found for company: ${company.id}");
      return [];
    }

    // Get the potential trainee IDs from this company
    final traineeIds = List<String>.from(company.potentialtrainee!);
    debugPrint("Found ${traineeIds.length} potential trainees for company: ${company.id}");

    return await _fetchStudentsByIds(traineeIds);
  }

  Future<List<String>> _collectPotentialTraineeIdsFromLinkedCompanies(Company company) async {
    final List<String> allIds = [];

    // Check if the company has an originalAuthority
    if (company.originalAuthority == null) {
      debugPrint("Company has no originalAuthority, cannot collect from linked companies");
      return allIds;
    }

    // Check if linkedCompanies exists and is not empty
    if (company.originalAuthority!.linkedCompanies == null ||
        company.originalAuthority!.linkedCompanies!.isEmpty) {
      debugPrint("No linked companies found for company");
      return allIds;
    }

    debugPrint("Collecting potential trainee IDs from ${company.originalAuthority!.linkedCompanies!.length} linked companies");

    // Get linked companies
    final linkedCompanies = await Future.wait(
        company.originalAuthority!.linkedCompanies!.map((id) => itcFirebaseLogic.getCompany(id))
    );

    // Collect potential trainee IDs
    for (final linkedCompany in linkedCompanies) {
      if (linkedCompany != null && linkedCompany.potentialtrainee != null) {
        // Safely convert to List<String>
        final traineeIds = List<String>.from(linkedCompany.potentialtrainee!);
        allIds.addAll(traineeIds);
        debugPrint("Added ${traineeIds.length} potential trainee IDs from company: ${linkedCompany.id}");
      }
    }

    // Return unique IDs
    final uniqueIds = allIds.toSet().toList();
    debugPrint("Total unique potential trainee IDs collected: ${uniqueIds.length}");
    return uniqueIds;
  }

  Future<List<Student>> _fetchStudentsByIds(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];

    debugPrint("Fetching ${studentIds.length} students by ID");

    final studentFutures = studentIds.map((id) => itcFirebaseLogic.getStudent(id));
    final studentsList = await Future.wait(studentFutures);

    final students = studentsList.whereType<Student>().toList();
    debugPrint("Successfully fetched ${students.length} students");
    return students;
  }
  late ITCFirebaseLogic itcFirebaseLogic ;


  Future<List<Student>> getPotentialStudents({Company? company}) async {
    debugPrint("get potenetial students ");
    if (company == null) return [];

    try {
      List<String> allPotentialTraineeIds = [];

      if (company.originalAuthority != null) {
        debugPrint("Processing company with original authority: ${company.originalAuthority!.id}");

        // This company has an authority company linked
        debugPrint("Processing company with linked authority: ${company.originalAuthority!.linkedCompanies}");

        // Use the authority company object directly - it already has linkedCompanies
        final authorityCompany = company.originalAuthority!;

        // Get all linked companies in parallel
        final linkedCompanies = await Future.wait(
            (authorityCompany.linkedCompanies ?? []).map((id) => itcFirebaseLogic.getCompany(id))
        );

        // Collect potential trainee IDs from all linked companies
        for (final linkedCompany in linkedCompanies) {
          if (linkedCompany != null && linkedCompany.potentialtrainee != null) {
            // Cast each item to String before adding
            final traineeIds = linkedCompany.potentialtrainee!
                .where((id) => id != null)
                .map((id) => id.toString())
                .toList();
            allPotentialTraineeIds.addAll(traineeIds);
          }
        }
      } else {
// This is a regular company, just use its own potential trainees
        debugPrint("Processing regular company: ${company.id}");
        if (company.potentialtrainee != null) {
          // Cast each item to String before adding
          final traineeIds = company.potentialtrainee!
              .where((id) => id != null)
              .map((id) => id.toString())
              .toList();
          allPotentialTraineeIds.addAll(traineeIds);
        }
      }

      // Remove duplicates (in case same student is in multiple companies)
      allPotentialTraineeIds = allPotentialTraineeIds.toSet().toList();

      debugPrint("Total unique potential trainees to fetch: ${allPotentialTraineeIds.length.toString()}");

      // Fetch all student objects in parallel
      final studentFutures = allPotentialTraineeIds.map((studentId) => itcFirebaseLogic.getStudent(studentId));
      final studentsList = await Future.wait(studentFutures);

      // Filter out nulls and get the list
      final students = studentsList.whereType<Student>().toList();

      debugPrint("Successfully fetched ${students.length} potential students");
      return students;

    } catch (e, s) {
      debugPrint('Error getting potential students: $e');
      debugPrintStack(stackTrace: s);
      return [];
    }
  }
  /// Fetch **all** companies under users/companies/companies
  Future<List<Company>> getAllCompanies() async {
    final snap = await _firestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .get();

    return snap.docs
        .map((d) => Company.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  // ─── INTERNSHIPS ───────────────────────────────────────────────────────────

  /// Fetch **every** internship posted by every company
  Future<List<IndustrialTraining>> getAllInternships() async {
    final companies = await _firestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .get();

    List<IndustrialTraining> all = [];
    for (var c in companies.docs) {
      final intSnap = await c.reference
          .collection('IT')
          .orderBy('postedAt', descending: true)
          .get();

      all.addAll(
        intSnap.docs.map(
          (d) => IndustrialTraining.fromMap(
            d.data() as Map<String, dynamic>,
            d.id,
          ),
        ),
      );
    }
    return all;
  }

  // ─── INTERNSHIP APPLICATIONS ──────────────────────────────────────────────

  /// Fetch **all** internship applications under every company→internship→applications
  Future<List<Application>> getAllApplications() async {
    final companies = await _firestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .get();

    List<Application> apps = [];
    for (var c in companies.docs) {
      final intSnap = await c.reference.collection('IT').get();

      for (var i in intSnap.docs) {
        final appSnap = await i.reference.collection('applications').get();

        apps.addAll(
          appSnap.docs.map(
            (d) => Application.fromMap(d.data() as Map<String, dynamic>, d.id),
          ),
        );
      }
    }
    return apps;
  }

  // Add a new admin
  Future<void> addAdmin(Admin admin) {
    return _firestore.collection('admins').doc(admin.uid).set(admin.toMap());
  }

  // Fetch a single admin
  Future<Admin?> getAdmin(String uid) async {
    final doc = await _firestore.collection('admins').doc(uid).get();

    if (!doc.exists) return null;
    return Admin.fromMap(doc.data()!, doc.id);
  }

  // Fetch all admins
  Future<List<Admin>> getAllAdmins() async {
    final snap = await _firestore.collection('admins').get();

    return snap.docs.map((d) => Admin.fromMap(d.data(), d.id)).toList();
  }

  // lib/itc_logic/firebase/admin_cloud.dart

  ///To fetch the approval that was made by a specific admin
  Stream<List<Approval>> getPendingApprovals(String id) {
    return _firestore
        .collection('admins')
        .doc(id)
        .collection('approvals')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Approval.fromFirestore(d)).toList(),
        );
  }

  ///To update approval status
  Future<void> updateApprovalStatus(
    String id, {
    required String approvalId,
    required String newStatus,
  }) {
    return _firestore
        .collection('admins')
        .doc(id)
        .collection('approvals')
        .doc(approvalId)
        .update({'status': newStatus});
  }

  /// Stream of all pending user reports
  Stream<List<Report>> getUserReports() {
    return _firestore
        .collection('reports') // or your path
        .where('status', isEqualTo: 'new') // only "new" ones
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Report.fromFirestore(d)).toList());
  }

  /// Mark a report resolved
  Future<void> resolveReport(String reportId) {
    return _firestore.collection('reports').doc(reportId).update({
      'status': 'resolved',
    });
  }

  /// 2️⃣ Total internships listings (remove landlord logic)
  Future<int> getTotalListings() async {
    // Count all internships under companies
    final companies = await _firestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .get();
    int count = 0;
    for (var c in companies.docs) {
      final itDocs = await c.reference.collection('IT').get();
      count += itDocs.size;
    }
    return count;
  }

  /// 3️⃣ Total new reports
  Future<int> getTotalNewReports() async {
    final snap = await _firestore
        .collection('reports')
        .where('status', isEqualTo: 'new')
        .get();
    return snap.size;
  }
}
