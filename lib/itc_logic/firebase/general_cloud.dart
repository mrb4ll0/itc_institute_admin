import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../model/admin.dart';
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
    debugPrint("before replace ${uid}");
     uid = uid.replaceAll("admin_", "");
    debugPrint("uid is ${uid}");
final adminDoc = await _firebaseFirestore
        .collection("admins")
        .doc(uid)
        .get();

    if (adminDoc.exists) {
      debugPrint("admin exist");
      return Admin.fromMap(companyDoc.data()!,companyDoc.id);
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

  // Method to get FCM tokens for notification sending
  Future<List<String>> getAllFCMTokens({String? specificUserId}) async {
    List<String> allTokens = [];

    try {
      // 1. Get all student tokens
      final studentSnapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .get();

      for (var doc in studentSnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        final userId = doc.id;

        // If specificUserId is provided, only add that user's token
        if (specificUserId != null) {
          if (userId == specificUserId && token != null && token.isNotEmpty) {
            allTokens.add(token);
            break; // Found the specific user
          }
        } else if (token != null && token.isNotEmpty) {
          allTokens.add(token);
        }
      }

      // If we're looking for a specific user and already found it, return early
      if (specificUserId != null && allTokens.isNotEmpty) {
        return allTokens;
      }

      // 2. Get all company tokens
      final companySnapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .get();

      for (var doc in companySnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        final userId = doc.id;

        if (specificUserId != null) {
          if (userId == specificUserId && token != null && token.isNotEmpty) {
            allTokens.add(token);
            break;
          }
        } else if (token != null && token.isNotEmpty) {
          allTokens.add(token);
        }
      }

      // If we're looking for a specific user and already found it, return early
      if (specificUserId != null && allTokens.isNotEmpty) {
        return allTokens;
      }

      // 3. Get all admin tokens
      final adminSnapshot = await _firebaseFirestore
          .collection('admins')
          .get();

      for (var doc in adminSnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        final userId = doc.id;

        if (specificUserId != null) {
          // Admins might have IDs prefixed differently
          if ((userId == specificUserId ||
              "admin_$userId" == specificUserId) &&
              token != null && token.isNotEmpty) {
            allTokens.add(token);
            break;
          }
        } else if (token != null && token.isNotEmpty) {
          allTokens.add(token);
        }
      }

      // Remove duplicates (in case any exist)
      allTokens = allTokens.toSet().toList();

      debugPrint('✅ Retrieved ${allTokens.length} FCM tokens');
      return allTokens;

    } catch (e, s) {
      debugPrint('❌ Error fetching FCM tokens: $e');
      debugPrint('Stack trace: $s');
      return allTokens; // Return empty list on error
    }
  }

  // Optional: Get FCM tokens by user role
  Future<List<String>> getFCMTokensByRole(String role) async {
    List<String> tokens = [];

    try {
      if (role == 'student') {
        final studentSnapshot = await _firebaseFirestore
            .collection(usersCollection)
            .doc('students')
            .collection('students')
            .get();

        for (var doc in studentSnapshot.docs) {
          final token = doc.data()['fcmToken'] as String?;
          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      }
      else if (role == 'company') {
        final companySnapshot = await _firebaseFirestore
            .collection(usersCollection)
            .doc('companies')
            .collection('companies')
            .get();

        for (var doc in companySnapshot.docs) {
          final token = doc.data()['fcmToken'] as String?;
          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      }
      else if (role == 'admin') {
        final adminSnapshot = await _firebaseFirestore
            .collection('admins')
            .get();

        for (var doc in adminSnapshot.docs) {
          final token = doc.data()['fcmToken'] as String?;
          if (token != null && token.isNotEmpty) {
            tokens.add(token);
          }
        }
      }

      debugPrint('✅ Retrieved ${tokens.length} FCM tokens for role: $role');
      return tokens;
    } catch (e, s) {
      debugPrint('❌ Error fetching FCM tokens for role $role: $e');
      return tokens;
    }
  }

  // Optional: Stream version for real-time token updates
  Stream<List<String>> getAllFCMTokensStream() {
    return _firebaseFirestore
        .collectionGroup(usersCollection) // This might need adjustment based on your structure
        .snapshots()
        .asyncMap((querySnapshot) async {
      List<String> tokens = [];

      // This is a simplified version - you might need to adjust
      // based on your exact Firestore structure
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      }

      return tokens.toSet().toList(); // Remove duplicates
    });
  }

  // Optional: Update a user's FCM token (call this when user logs in)
  Future<void> updateUserFCMToken(String token) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final uid = currentUser.uid;

    try {
      // Try to update in student collection
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('students')
          .collection('students')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      // Try to update in company collection
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      debugPrint('✅ FCM token updated for user: $uid');
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }

}
