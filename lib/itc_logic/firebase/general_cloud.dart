import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../model/admin.dart';
import '../../model/authority.dart';
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
        Company company = Company.fromMap(doc.data()!);
        return company;
      }
    } catch (e, s) {
      debugPrint(e.toString());
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

  
  // ---------------------- AUTHORITY ----------------------

  /// Register an authority (call from Firebase Auth registration)
  static Future<void> registerAuthority(
      String uid,
      Map<String, dynamic> authorityData,
      ) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc('authorities')
        .collection('authorities')
        .doc(uid)
        .set({
      ...authorityData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Also create in main authorities collection for easy querying
    await FirebaseFirestore.instance
        .collection('authorities')
        .doc(uid)
        .set({
      ...authorityData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a new authority
  Future<void> addAuthority(Authority authority) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    // Add to authorities collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc('authorities')
        .collection('authorities')
        .doc(authority.id)
        .set(authority.toMap());

    // Also store in main authorities collection for easy access
    await FirebaseFirestore.instance
        .collection('authorities')
        .doc(authority.id)
        .set(authority.toMap());
  }

  /// Get authority by UID
  Future<Authority?> getAuthority(String uid) async {
    try {
      // Try users/authorities collection first
      final doc = await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .doc(uid)
          .get();

      if (doc.exists) {
        debugPrint("Authority exists in users collection");
        return Authority.fromMap(doc.data()!);
      }

      // Try main authorities collection as fallback
      final mainDoc = await _firebaseFirestore
          .collection('authorities')
          .doc(uid)
          .get();

      if (mainDoc.exists) {
        debugPrint("Authority exists in main collection");
        return Authority.fromMap(mainDoc.data()!);
      }

    } catch (e, s) {
      debugPrint("Error fetching authority: $e");
      debugPrintStack(stackTrace: s);
    }
    return null;
  }

  /// Get authority by email
  Future<Authority?> getAuthorityByEmail(String email) async {
    try {
      final querySnapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Authority.fromMap(doc.data());
      }

      // Try main collection
      final mainQuery = await _firebaseFirestore
          .collection('authorities')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (mainQuery.docs.isNotEmpty) {
        final doc = mainQuery.docs.first;
        return Authority.fromMap(doc.data());
      }

    } catch (e) {
      debugPrint("Error fetching authority by email: $e");
    }
    return null;
  }

  /// Stream for real-time authority updates
  Stream<Authority> authorityStream(String uid) {
    return _firebaseFirestore
        .collection(usersCollection)
        .doc('authorities')
        .collection('authorities')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Authority.fromMap(doc.data()!);
      }
      throw Exception("Authority not found");
    });
  }

  /// Update authority data
  Future<void> updateAuthority(String uid, Map<String, dynamic> updates) async {
    try {
      // Update in users collection
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .doc(uid)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update in main collection
      await _firebaseFirestore
          .collection('authorities')
          .doc(uid)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Authority $uid updated successfully");
    } catch (e) {
      debugPrint("❌ Error updating authority: $e");
      rethrow;
    }
  }

  /// Get all authorities (for dropdowns, etc.)
  Future<List<Authority>> getAllAuthorities({bool activeOnly = true}) async {
    try {
      Query query = _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities');

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return Authority.fromMap(doc.data() as Map<String,dynamic>);
      }).toList();

    } catch (e) {
      debugPrint("Error fetching all authorities: $e");
      return [];
    }
  }

  /// Get stream of all authorities
  Stream<List<Authority>> authoritiesStream({bool activeOnly = true}) {
    Query query = _firebaseFirestore
        .collection(usersCollection)
        .doc('authorities')
        .collection('authorities');

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Authority.fromMap(doc.data() as Map<String,dynamic>);
      }).toList();
    });
  }

  /// Link a company to an authority (when company registers under authority)
  Future<void> linkCompanyToAuthority({
    required String companyId,
    required String authorityId,
    required String companyName,
  }) async {
    try {
      // Add company to authority's linkedCompanies
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId)
          .update({
        'linkedCompanies': FieldValue.arrayUnion([companyId]),
      });

      // Add to main collection too
      await _firebaseFirestore
          .collection('authorities')
          .doc(authorityId)
          .update({
        'linkedCompanies': FieldValue.arrayUnion([companyId]),
      });

      // Update company's authority status
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .update({
        'authorityLinkStatus': 'PENDING',
      });

      // Create notification for authority
      await _createAuthorityNotification(
        authorityId: authorityId,
        companyId: companyId,
        companyName: companyName,
        type: 'NEW_FACILITY_REQUEST',
        message: '$companyName wants to register under your authority',
      );

      debugPrint("✅ Company $companyId linked to authority $authorityId");
    } catch (e) {
      debugPrint("❌ Error linking company to authority: $e");
      rethrow;
    }
  }

  /// Approve/Reject a company's request to link to authority
  Future<void> processAuthorityLinkRequest({
    required String authorityId,
    required String companyId,
    required bool isApproved,
    String? remarks,
  }) async {
    try {
      final status = isApproved ? 'APPROVED' : 'REJECTED';

      // Update company's authority status
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('companies')
          .collection('companies')
          .doc(companyId)
          .update({
        'authorityLinkStatus': status,
        'authorityRemarks': remarks,
        'authorityActionDate': FieldValue.serverTimestamp(),
      });

      if (isApproved) {
        // Add to approved list in authority
        await _firebaseFirestore
            .collection(usersCollection)
            .doc('authorities')
            .collection('authorities')
            .doc(authorityId)
            .update({
          'approvedCompanies': FieldValue.arrayUnion([companyId]),
        });

        // Remove from pending if exists
        await _firebaseFirestore
            .collection('authorities')
            .doc(authorityId)
            .update({
          'pendingCompanies': FieldValue.arrayRemove([companyId]),
        });
      } else {
        // Add to rejected list
        await _firebaseFirestore
            .collection('authorities')
            .doc(authorityId)
            .update({
          'rejectedCompanies': FieldValue.arrayUnion([companyId]),
          'pendingCompanies': FieldValue.arrayRemove([companyId]),
        });
      }

      // Notify company
      await _createCompanyNotification(
        companyId: companyId,
        type: 'AUTHORITY_LINK_DECISION',
        message: isApproved
            ? 'Your request to link with authority has been approved'
            : 'Your request to link with authority has been rejected',
        data: {
          'authorityId': authorityId,
          'status': status,
          'remarks': remarks,
        },
      );

      debugPrint("✅ Authority link request processed for company $companyId: $status");
    } catch (e) {
      debugPrint("❌ Error processing authority link request: $e");
      rethrow;
    }
  }

  /// Get all companies under an authority
  Future<List<Company>> getCompaniesUnderAuthority(String authorityId) async {
    try {
      // Get company IDs from authority
      final authorityDoc = await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId)
          .get();

      if (!authorityDoc.exists) return [];

      final authority = Authority.fromMap(authorityDoc.data()!);
      final companyIds = authority.linkedCompanies;

      if (companyIds.isEmpty) return [];

      // Fetch companies in batches
      List<Company> companies = [];

      for (int i = 0; i < companyIds.length; i += 10) {
        final batchIds = companyIds.sublist(
          i,
          i + 10 > companyIds.length ? companyIds.length : i + 10,
        );

        final querySnapshot = await _firebaseFirestore
            .collection(usersCollection)
            .doc('companies')
            .collection('companies')
            .where('id', whereIn: batchIds)
            .get();

        for (var doc in querySnapshot.docs) {
          companies.add(Company.fromMap(doc.data()));
        }
      }

      return companies;
    } catch (e) {
      debugPrint("Error fetching companies under authority: $e");
      return [];
    }
  }

  /// Helper: Create authority notification
  Future<void> _createAuthorityNotification({
    required String authorityId,
    required String companyId,
    required String companyName,
    required String type,
    required String message,
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .add({
      'authorityId': authorityId,
      'companyId': companyId,
      'companyName': companyName,
      'type': type,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'category': 'authority',
    });
  }

  /// Helper: Create company notification
  Future<void> _createCompanyNotification({
    required String companyId,
    required String type,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .add({
      'companyId': companyId,
      'type': type,
      'message': message,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'category': 'company',
    });
  }

  // ---------------------- UPDATE getUserById METHOD ----------------------

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

    // 🔽 NEW: Try fetching as Authority
    final authorityDoc = await _firebaseFirestore
        .collection(usersCollection)
        .doc('authorities')
        .collection('authorities')
        .doc(uid)
        .get();

    if (authorityDoc.exists) {
      return Authority.fromMap(authorityDoc.data()!);
    }

    // Try as Admin
    final adminId = uid.replaceAll("admin_", "");
    final adminDoc = await _firebaseFirestore
        .collection("admins")
        .doc(adminId)
        .get();

    if (adminDoc.exists) {
      return Admin.fromMap(adminDoc.data()!, adminDoc.id);
    }

    return null;
  }

  // ---------------------- UPDATE getUserByEmail METHOD ----------------------

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    // Updated roles list to include authorities
    final List<String> roles = ['students', 'companies', 'authorities'];

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
          'role': role.substring(0, role.length - 1), // "authorities" -> "authority"
          ...doc.data(),
        };
      }
    }

    return null; // No user found
  }

  // ---------------------- UPDATE FCM TOKEN METHODS ----------------------

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

        if (specificUserId != null) {
          if (userId == specificUserId && token != null && token.isNotEmpty) {
            allTokens.add(token);
            break;
          }
        } else if (token != null && token.isNotEmpty) {
          allTokens.add(token);
        }
      }

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

      if (specificUserId != null && allTokens.isNotEmpty) {
        return allTokens;
      }

      // 🔽 NEW: 3. Get all authority tokens
      final authoritySnapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .get();

      for (var doc in authoritySnapshot.docs) {
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

      if (specificUserId != null && allTokens.isNotEmpty) {
        return allTokens;
      }

      // 4. Get all admin tokens
      final adminSnapshot = await _firebaseFirestore
          .collection('admins')
          .get();

      for (var doc in adminSnapshot.docs) {
        final data = doc.data();
        final token = data['fcmToken'] as String?;
        final userId = doc.id;

        if (specificUserId != null) {
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

      // Remove duplicates
      allTokens = allTokens.toSet().toList();

      debugPrint('✅ Retrieved ${allTokens.length} FCM tokens');
      return allTokens;

    } catch (e, s) {
      debugPrint('❌ Error fetching FCM tokens: $e');
      debugPrint('Stack trace: $s');
      return allTokens;
    }
  }

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
      else if (role == 'authority') {
        final authoritySnapshot = await _firebaseFirestore
            .collection(usersCollection)
            .doc('authorities')
            .collection('authorities')
            .get();

        for (var doc in authoritySnapshot.docs) {
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

      // 🔽 NEW: Try to update in authority collection
      await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      debugPrint('✅ FCM token updated for user: $uid');
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }

  // Optional: Get authorities for dropdown (active and approved)
  Future<List<Map<String, dynamic>>> getAuthoritiesForDropdown() async {
    try {
      final querySnapshot = await _firebaseFirestore
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .where('isActive', isEqualTo: true)
          .where('isApproved', isEqualTo: true)
          .orderBy('name')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
        };
      }).toList();

    } catch (e) {
      debugPrint("Error fetching authorities for dropdown: $e");
      return [];
    }
  }


  Future<bool> addCompanyToAuthorityPendingApplications({
    required String authorityId,
    required String companyId,
    required String companyName,
    required String selectedAuthorityName
  }) async {
    try {
      // Add company to authority's pending applications
      await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId)
          .update({
        'pendingApplications': FieldValue.arrayUnion([companyId]),
      });

      // You might also want to create an application record
      // This is optional but recommended for tracking
      await FirebaseFirestore.instance
          .collection('authority_applications')
          .add({
        'companyId': companyId,
        'companyName': companyName,
        'authorityId': authorityId,
        'authorityName': selectedAuthorityName,
        'status': 'PENDING',
        'applicationDate': DateTime.now().toIso8601String(),
        'decisionDate': null,
        'remarks': null,
      });
      return true;
    } catch (e) {
      rethrow;
    }
  }

}
