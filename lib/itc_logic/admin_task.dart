import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authority.dart';
import '../model/admin.dart';
import '../model/application.dart';
import '../model/approval.dart';
import '../model/company.dart';
import '../model/internship_model.dart';
import '../model/report.dart';
import '../model/student.dart';
import 'localDB/sharedPreference.dart';

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

  // Add this method to find and return either a Company or Authority object based on an email
  Future<dynamic> getCompanyOrAuthorityByEmail(String email) async {
    try {
      // First, search in companies collection
      final companiesSnapshot = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (companiesSnapshot.docs.isNotEmpty) {
        final companyData = companiesSnapshot.docs.first.data() as Map<String, dynamic>;
        final company = Company.fromMap(companyData);

        // Check if this is an authority company (has linked companies)
        if (_isAuthorityCompany(company)) {
          debugPrint("Found authority company with email: $email");
          return company;
        } else {
          debugPrint("Found regular company with email: $email");
          return company;
        }
      }

      // If not found in companies, search in authorities collection
      final authoritiesSnapshot = await _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (authoritiesSnapshot.docs.isNotEmpty) {
        debugPrint("Found authority with email: $email");
        // Assuming you have an Authority model class
        // If not, you'll need to create one or return a Map
        final authorityData = Authority.fromMap(authoritiesSnapshot.docs.first.data());
        // Return authority object (you'll need to implement Authority.fromMap)
        // For now, returning the data map. You should create an Authority class.
        return authorityData;
      }

      debugPrint("No company or authority found with email: $email");
      return null;

    } catch (e, s) {
      debugPrint('Error finding company/authority by email: $e');
      debugPrintStack(stackTrace: s);
      return null;
    }
  }

// Add this method to lock a user account (company, authority, or student)
  Future<bool> lockAccount(String userId, String userType) async {
    try {
      // Validate user type
      if (!['company', 'authority', 'student'].contains(userType)) {
        debugPrint('Invalid user type: $userType. Must be company, authority, or student');
        return false;
      }

      String collectionPath;

      // Determine the correct collection path based on user type
      switch (userType) {
        case 'company':
          collectionPath = 'users/companies/companies';
          break;
        case 'authority':
          collectionPath = 'users/authorities/authorities';
          break;
        case 'student':
          collectionPath = 'users/students/students';
          break;
        default:
          return false;
      }

      // Update the user document to mark it as locked
      await _firestore
          .collection(collectionPath)
          .doc(userId)
          .update({
        'isLocked': true,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedBy': globalUserId, // Track which admin locked the account
      });

      debugPrint('Successfully locked $userType account with ID: $userId');

      // Optional: Add to a separate collection for audit trail
      await _firestore
          .collection('locked_accounts')
          .doc(userId)
          .set({
        'userId': userId,
        'userType': userType,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedBy': globalUserId,
        'isLocked': true,
      });

      return true;

    } catch (e, s) {
      debugPrint('Error locking account: $e');
      debugPrintStack(stackTrace: s);
      return false;
    }
  }

// Optional: Add an unlock method as well for completeness
  Future<bool> unlockAccount(String userId, String userType) async {
    try {
      if (!['company', 'authority', 'student'].contains(userType)) {
        debugPrint('Invalid user type: $userType');
        return false;
      }

      String collectionPath;
      switch (userType) {
        case 'company':
          collectionPath = 'users/companies/companies';
          break;
        case 'authority':
          collectionPath = 'users/authorities/authorities';
          break;
        case 'student':
          collectionPath = 'users/students/students';
          break;
        default:
          return false;
      }

      await _firestore
          .collection(collectionPath)
          .doc(userId)
          .update({
        'isLocked': false,
        'unlockedAt': FieldValue.serverTimestamp(),
        'unlockedBy': globalUserId,
      });

      // Update audit trail
      await _firestore
          .collection('locked_accounts')
          .doc(userId)
          .update({
        'isLocked': false,
        'unlockedAt': FieldValue.serverTimestamp(),
        'unlockedBy': globalUserId,
      });

      debugPrint('Successfully unlocked $userType account with ID: $userId');
      return true;

    } catch (e, s) {
      debugPrint('Error unlocking account: $e');
      debugPrintStack(stackTrace: s);
      return false;
    }
  }



  // Add these methods to AdminCloud class

  /// Get cloud lock details for a user
  Future<Map<String, dynamic>> getCloudLockDetails(String email) async {
    try {
      // First, find the user by email
      final userData = await getCompanyOrAuthorityByEmail(email);

      if (userData == null) {
        // Check if it's a student
        final studentSnapshot = await _firestore
            .collection('users')
            .doc('students')
            .collection('students')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data();
          return {
            'isLocked': studentData['isLocked'] ?? false,
            'reason': studentData['lockReason'],
            'lockedAt': studentData['lockedAt'],
            'lockedBy': studentData['lockedBy'],
            'lockDuration': studentData['lockDuration'],
            'isPermanent': studentData['lockDuration'] == null,
            'userType': 'student',
            'userId': studentSnapshot.docs.first.id,
          };
        }

        return {'isLocked': false};
      }

      // Handle company or authority
      final isLocked = userData['isLocked'] ?? false;
      final isPermanent = userData['lockDuration'] == null;

      return {
        'isLocked': isLocked,
        'reason': userData['lockReason'],
        'lockedAt': userData['lockedAt'],
        'lockedBy': userData['lockedBy'],
        'lockDuration': userData['lockDuration'],
        'isPermanent': isPermanent,
        'userType': userData is Company ? 'company' : 'authority',
        'userId': userData.id,
      };

    } catch (e, stackTrace) {
      debugPrint('❌ Error getting cloud lock details: $e');
      debugPrintStack(stackTrace: stackTrace);
      return {'isLocked': false, 'error': e.toString()};
    }
  }

  /// Check if a user is locked in cloud (Firebase)
  Future<bool> isUserLockedInCloud(String email) async {
    try {
      final details = await getCloudLockDetails(email);
      return details['isLocked'] == true;
    } catch (e) {
      debugPrint('❌ Error checking cloud lock: $e');
      return false;
    }
  }

  /// Lock account with duration in cloud (Firebase)
  Future<bool> lockAccountWithDuration({
    required String userId,
    required String userType,
    required String email,
    Duration? duration,
    String? reason,
  }) async {
    try {
      if (!['company', 'authority', 'student'].contains(userType)) {
        debugPrint('Invalid user type: $userType');
        return false;
      }

      String collectionPath;
      switch (userType) {
        case 'company':
          collectionPath = 'users/companies/companies';
          break;
        case 'authority':
          collectionPath = 'users/authorities/authorities';
          break;
        case 'student':
          collectionPath = 'users/students/students';
          break;
        default:
          return false;
      }

      final updateData = {
        'isLocked': true,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedBy': globalUserId,
        'lockReason': reason ?? 'No reason provided',
      };

      // Add duration if specified
      if (duration != null) {
        updateData['lockDuration'] = duration.inSeconds;
        updateData['lockExpiry'] = Timestamp.fromDate(DateTime.now().add(duration));
      }
      await _firestore.collection(collectionPath).doc(userId).update(updateData);

      // Update audit trail
      await _firestore.collection('locked_accounts').doc(userId).set({
        'userId': userId,
        'userType': userType,
        'email': email,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedBy': globalUserId,
        'lockReason': reason,
        'lockDuration': duration?.inSeconds,
        'isLocked': true,
      }, SetOptions(merge: true));

      // Also save to local SharedPreferences for faster access
      await UserPreferences.lockAccount(
        email: email,
        duration: duration,
        reason: reason,
        lockedBy: globalUserId,
      );

      debugPrint('✅ Locked $userType account: $email (duration: ${duration?.inHours ?? 'permanent'} hours)');
      return true;

    } catch (e, s) {
      debugPrint('❌ Error locking account with duration: $e');
      debugPrintStack(stackTrace: s);
      return false;
    }
  }

  /// Unlock account in cloud (Firebase)
  Future<bool> unlockAccountInCloud(String userId, String userType, String email) async {
    try {
      if (!['company', 'authority', 'student'].contains(userType)) {
        debugPrint('Invalid user type: $userType');
        return false;
      }

      String collectionPath;
      switch (userType) {
        case 'company':
          collectionPath = 'users/companies/companies';
          break;
        case 'authority':
          collectionPath = 'users/authorities/authorities';
          break;
        case 'student':
          collectionPath = 'users/students/students';
          break;
        default:
          return false;
      }

      await _firestore.collection(collectionPath).doc(userId).update({
        'isLocked': false,
        'unlockedAt': FieldValue.serverTimestamp(),
        'unlockedBy': globalUserId,
      });

      // Update audit trail
      await _firestore.collection('locked_accounts').doc(userId).update({
        'isLocked': false,
        'unlockedAt': FieldValue.serverTimestamp(),
        'unlockedBy': globalUserId,
      });

      // Also update local SharedPreferences
      await UserPreferences.unlockAccount(email, autoUnlock: false);

      debugPrint('✅ Unlocked $userType account: $email');
      return true;

    } catch (e, s) {
      debugPrint('❌ Error unlocking account in cloud: $e');
      debugPrintStack(stackTrace: s);
      return false;
    }
  }

  /// Auto-check and sync all locks (call on app startup)
  Future<void> syncAllAccountLocks() async {
    try {
      // Get all locked accounts from cloud
      final lockedAccountsSnapshot = await _firestore
          .collection('locked_accounts')
          .where('isLocked', isEqualTo: true)
          .get();

      for (var doc in lockedAccountsSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String?;
        final lockDuration = data['lockDuration'] as int?;
        final lockedAt = (data['lockedAt'] as Timestamp?)?.toDate();

        if (email == null) continue;

        // Check if lock has expired
        if (lockDuration != null && lockedAt != null) {
          final expiryTime = lockedAt.add(Duration(seconds: lockDuration));
          if (DateTime.now().isAfter(expiryTime)) {
            // Auto-unlock expired lock
            await unlockAccountInCloud(doc.id, data['userType'], email);
            debugPrint('🔓 Auto-unlocked expired account: $email');
          } else {
            // Sync to local
            await UserPreferences.lockAccount(
              email: email,
              duration: expiryTime.difference(DateTime.now()),
              reason: data['lockReason'],
              lockedBy: data['lockedBy'],
            );
          }
        } else if (lockDuration == null) {
          // Permanent lock - sync to local
          await UserPreferences.lockAccount(
            email: email,
            duration: null, // Permanent
            reason: data['lockReason'],
            lockedBy: data['lockedBy'],
          );
        }
      }

      debugPrint('✅ Synced ${lockedAccountsSnapshot.docs.length} locked accounts');

    } catch (e, stackTrace) {
      debugPrint('❌ Error syncing account locks: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Sync lock status for a specific user by email
  Future<void> syncUserAccountLock(String email) async {
    try {
      if (email.isEmpty) {
        debugPrint('❌ Cannot sync: Email is empty');
        return;
      }

      debugPrint('🔄 Syncing lock status for email: $email');

      // Query the locked_accounts collection for this specific email
      final lockedAccountSnapshot = await _firestore
          .collection('locked_accounts')
          .where('email', isEqualTo: email)
          .where('isLocked', isEqualTo: true)
          .limit(1) // Only need the most recent/latest lock record
          .get();

      // If no locked account found in cloud, ensure local is unlocked
      if (lockedAccountSnapshot.docs.isEmpty) {
        debugPrint('📭 No locked account found in cloud for: $email');

        // Check if local has lock data for this user
        final localLockStatus = await UserPreferences.getLockStatus(email);
        if (localLockStatus['isLocked'] == true) {
          // Local says locked but cloud says not locked - clear local
          await UserPreferences.unlockAccount(email, autoUnlock: true);
          debugPrint('🔓 Cleared stale local lock for: $email');
        }
        return;
      }

      // Process the locked account data
      final doc = lockedAccountSnapshot.docs.first;
      final data = doc.data();
      final lockDuration = data['lockDuration'] as int?;
      final lockedAt = (data['lockedAt'] as Timestamp?)?.toDate();
      final lockReason = data['lockReason'] as String?;
      final lockedBy = data['lockedBy'] as String?;
      final userType = data['userType'] as String?;

      // Check if lock has expired
      if (lockDuration != null && lockedAt != null) {
        final expiryTime = lockedAt.add(Duration(seconds: lockDuration));

        if (DateTime.now().isAfter(expiryTime)) {
          // Lock has expired - auto-unlock in cloud
          if (userType != null) {
            await unlockAccountInCloud(doc.id, userType, email);
            debugPrint('🔓 Auto-unlocked expired account: $email');
          }

          // Also clear local lock
          await UserPreferences.unlockAccount(email, autoUnlock: true);
          debugPrint('🔓 Cleared expired local lock for: $email');

        } else {
          // Lock is still active - sync to local with remaining time
          final remainingTime = expiryTime.difference(DateTime.now());
          await UserPreferences.lockAccount(
            email: email,
            duration: remainingTime,
            reason: lockReason,
            lockedBy: lockedBy,
          );
          debugPrint('🔄 Synced active lock for: $email (${remainingTime.inMinutes} minutes remaining)');
        }

      } else if (lockDuration == null) {
        // Permanent lock - sync to local
        await UserPreferences.lockAccount(
          email: email,
          duration: null, // Permanent
          reason: lockReason,
          lockedBy: lockedBy,
        );
        debugPrint('🔄 Synced permanent lock for: $email');
      }

      debugPrint('✅ Successfully synced lock status for: $email');

    } catch (e, stackTrace) {
      debugPrint('❌ Error syncing account lock for $email: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
