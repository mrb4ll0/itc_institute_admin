import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:rxdart/rxdart.dart';

import '../../model/admin.dart';
import '../../model/authority.dart';
import '../../model/company.dart';
import '../../model/student.dart';
import '../../model/userProfile.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches a user by ID, checking both company and student collections
  /// Returns a UserConverter if found, null otherwise
  Future<UserConverter?> getUser(String userId) async {
    try {
      // First, check in companies collection
      final companyDoc = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(userId)
          .get();

      if (companyDoc.exists) {
        final companyData = companyDoc.data()!;
        final company = Company.fromMap({
          ...companyData,
          'id': companyDoc.id, // Ensure ID is included
        });
        return UserConverter(company);
      }
final authorityDoc = await _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .doc(userId)
          .get();

      if (authorityDoc.exists) {
        final companyData = authorityDoc.data()!;
        final authority = Authority.fromMap({
          ...companyData,
        });

        final company = AuthorityCompanyMapper.createCompanyFromAuthority(authority: authority);
        return UserConverter(company);
      }

      // If not found in companies, check in students collection
      final studentDoc = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(userId)
          .get();

      if (studentDoc.exists) {
        final studentData = studentDoc.data()!;
        final student = Student.fromFirestore(studentData, studentDoc.id);
        return UserConverter(student);
      }

      // If not found in either collection, check admin collection
      userId = userId.replaceAll("admin_", '');
      final adminDoc = await _firestore.collection('admins').doc(userId).get();

      if (adminDoc.exists) {
        final adminData = adminDoc.data()!;
        final admin = Admin.fromMap(adminData, adminDoc.id);
        admin.uid = 'admin_${userId}';
        return UserConverter(admin);
      }

      // User not found


      return null;
    } catch (e,s) {
      debugPrint('Error fetching user: $e');
      debugPrintStack(stackTrace: s);
      return null;
    }
  }

  /// Alternative: Check all collections in parallel for better performance
  Future<UserConverter?> getUserParallel(String userId) async {
    try {
      // Query all collections in parallel
      final futures = [
        _firestore.collection('companies').doc(userId).get(),
        _firestore
            .collection('users')
            .doc('students')
            .collection('students')
            .doc(userId)
            .get(),
        _firestore.collection('admins').doc(userId).get(),
      ];

      final results = await Future.wait(futures);
      final companyDoc = results[0] as DocumentSnapshot;
      final studentDoc = results[1] as DocumentSnapshot;
      final adminDoc = results[2] as DocumentSnapshot;

      // Check in priority order
      if (companyDoc.exists) {
        final companyData = companyDoc.data()!;
        return UserConverter(
          Company.fromMap(companyData as Map<String, double>),
        );
      }

      if (studentDoc.exists) {
        final studentData = studentDoc.data()!;
        return UserConverter(
          Student.fromFirestore(
            studentData as Map<String, dynamic>,
            studentDoc.id,
          ),
        );
      }

      if (adminDoc.exists) {
        final adminData = adminDoc.data()!;
        return UserConverter(
          Admin.fromMap(adminData as Map<String, dynamic>, adminDoc.id),
        );
      }

      return null;
    } catch (e) {
      print('Error fetching user in parallel: $e');
      return null;
    }
  }

  /// Enhanced version with role hint for better performance
  Future<UserConverter?> getUserWithRole(String userId, {String? role}) async {
    try {
      // If role is known, query specific collection
      if (role != null) {
        switch (role.toLowerCase()) {
          case 'company':
            final doc = await _firestore
                .collection('companies')
                .doc(userId)
                .get();
            if (doc.exists) {
              return UserConverter(
                Company.fromMap({...doc.data()!, 'id': doc.id}),
              );
            }
            break;

          case 'student':
            final doc = await _firestore
                .collection('users')
                .doc('students')
                .collection('students')
                .doc(userId)
                .get();
            if (doc.exists) {
              return UserConverter(
                Student.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              );
            }
            break;

          case 'admin':
            final doc = await _firestore.collection('admins').doc(userId).get();
            if (doc.exists) {
              return UserConverter(Admin.fromMap(doc.data()!, doc.id));
            }
            break;
        }
      }

      // If role not provided or not found with role hint, fall back to generic search
      return getUser(userId);
    } catch (e) {
      print('Error fetching user with role hint: $e');
      return null;
    }
  }

  /// Get current logged-in user as UserConverter
  Future<UserConverter?> getCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    return getUser(currentUser.uid);
  }

  /// Stream version for real-time updates
  Stream<UserConverter?> getUserStream(String userId) {
    // Create streams for all possible collections
    final companyStream = _firestore
        .collection('companies')
        .doc(userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? UserConverter(
                  Company.fromMap({...snapshot.data()!, 'id': snapshot.id}),
                )
              : null,
        );

    final studentStream = _firestore
        .collection('users')
        .doc('students')
        .collection('students')
        .doc(userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? UserConverter(
                  Student.fromFirestore(
                    snapshot.data() as Map<String, dynamic>,
                    snapshot.id,
                  ),
                )
              : null,
        );

    final adminStream = _firestore
        .collection('admins')
        .doc(userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? UserConverter(Admin.fromMap(snapshot.data()!, snapshot.id))
              : null,
        );

    // Combine streams - emits when any stream has data
    return Rx.combineLatest3<
      UserConverter?,
      UserConverter?,
      UserConverter?,
      UserConverter?
    >(companyStream, studentStream, adminStream, (
      companyUser,
      studentUser,
      adminUser,
    ) {
      return companyUser ?? studentUser ?? adminUser;
    });
  }
}
