import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/admin.dart';
import '../model/application.dart';
import '../model/approval.dart';
import '../model/company.dart';
import '../model/internship_model.dart';
import '../model/report.dart';
import '../model/student.dart';

class AdminCloud {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── USERS ────────────────────────────────────────────────────────────────

  /// Fetch **all** students under users/students/students
  Future<List<Student>> getAllStudents() async {
    final snap = await _firestore
        .collection('users')
        .doc('students')
        .collection('students')
        .get();

    return snap.docs
        .map((d) => Student.fromFirestore(d.data()!, d.id))
        .toList();
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
