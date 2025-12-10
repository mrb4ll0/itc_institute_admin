import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../model/company.dart';
import '../../model/institution_model.dart';
import '../../model/internship_model.dart';
import '../../model/student.dart';

class ITCFirebaseLogic {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final CollectionReference _institutionRef = FirebaseFirestore.instance
      .collection('institutions');

  final String usersCollection = 'users';

  //-------------------Institution ------------------------

  Future<List<Institution>> getInstitutions() async {
    final snapshot = await _institutionRef.get();

    return snapshot.docs
        .map((data) => Institution.fromMap(data.data() as Map<String, dynamic>))
        .toList();
  }

  // ---------------------- STUDENT ----------------------
  static Future<void> registerStudent(
    String uid,
    Map<String, dynamic> studentData,
  ) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc('students')
        .collection('students')
        .doc(uid)
        .set({...studentData, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> addStudent(Student student) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    await ITCFirebaseLogic.registerStudent(currentUser.uid, {
      ...student.toMap(),
      'role': 'student',
    });
  }

  Future<Student?> getStudent(String uid) async {
    final doc = await _firebaseFirestore
        .collection(usersCollection)
        .doc('students')
        .collection('students')
        .doc(uid)
        .get();

    if (doc.exists) {
      return Student.fromFirestore(doc.data()!, uid);
    }
    return null;
  }

  Stream<Student> studentStream(String uid) {
    return _firebaseFirestore
        .collection(usersCollection)
        .doc('students')
        .collection('students')
        .doc(uid)
        .snapshots()
        .map((doc) => Student.fromFirestore(doc.data()!, uid));
  }

  // ---------------------- COMPANY ----------------------
  Future<void> addCompany(Company company) async {
    await _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(company.id)
        .set({...company.toMap()});
  }

  Future<Company?> getCompany(String uid) async {
    try {
      final doc = await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(uid)
          .get();

      if (doc.exists) {
        debugPrint("company exist");
        Company company = Company.fromMap(doc.data()!);
        return company;
      }
    } catch (e, s) {
      debugPrint(e.toString());
    }
    return null;
  }

  Future<dynamic> getUserById(String uid) async {
    // Try fetching as Student
    final studentDoc = await _firebaseFirestore
        .collection(usersCollection)
        .doc('students')
        .collection('students')
        .doc(uid)
        .get();

    if (studentDoc.exists) {
      return Student.fromFirestore(studentDoc.data()!, uid);
    }

    // Try fetching as Company
    final companyDoc = await _firebaseFirestore
        .collection(usersCollection)
        .doc('companies')
        .collection('companies')
        .doc(uid)
        .get();

    if (companyDoc.exists) {
      return Company.fromMap(companyDoc.data()!);
    }

    return null;
  }

  // Fetch all internships stream across all companies
  Stream<List<IndustrialTraining>> getAllInternshipsStream() {
    return _firebaseFirestore
        .collectionGroup('IT')
        .orderBy('postedAt', descending: true)
        .snapshots()
        .asyncMap((internshipSnapshot) async {
          List<IndustrialTraining> internships = [];
          for (var doc in internshipSnapshot.docs) {
            final data = doc.data();
            final companyRef = data['company'];
            debugPrint("compRef ${companyRef.toString()}");
            if (companyRef != null) {
              final company = await getCompany(companyRef['id']);
              if (company != null) {
                IndustrialTraining it = IndustrialTraining.fromMap(
                  data,
                  doc.id,
                );
                it.company = company;
                internships.add(it);
              }
            }
          }
          return internships;
        });
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final List<String> roles = ['students', 'companies'];

    for (String role in roles) {
      final querySnapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc(role)
          .collection(role)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return {
          'uid': doc.id,
          'role': role.substring(
            0,
            role.length - 1,
          ), // convert "students" to "student"
          ...doc.data(),
        };
      }
    }

    return null; // No user found
  }

  Future<void> updateStudentSchoolAndMatric({
    required String school,
    required String matricNumber,
    required String department,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("No logged in user found");
    }

    final uid = currentUser.uid;

    try {
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(uid)
          .set(
            {
              'school': school,
              'matricNumber': matricNumber,
              'updatedAt': FieldValue.serverTimestamp(),
              'department': department,
            },
            SetOptions(
              merge: true,
            ), // ensures we only update/merge these fields
          );

      debugPrint("✅ Student ($uid) updated with school & matric number");
    } catch (e, s) {
      debugPrint("❌ Failed to update student: $e");
      rethrow;
    }
  }

  Future<bool> hasCompletedInstitutionInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("No logged in user found");
    }

    final uid = currentUser.uid;

    try {
      final doc = await _firebaseFirestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(uid)
          .get();

      if (!doc.exists) {
        return false; // no student document yet
      }

      final data = doc.data();
      if (data == null) return false;

      final school = data['school'] as String?;
      final matricNumber = data['matricNumber'] as String?;

      // Check both are not null and not empty
      if (school != null &&
          school.trim().isNotEmpty &&
          matricNumber != null &&
          matricNumber.trim().isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("❌ Error checking institution info: $e");
      return false;
    }
  }
}
