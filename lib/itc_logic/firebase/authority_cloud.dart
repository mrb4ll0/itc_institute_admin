import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../model/authority.dart';
import '../../model/company.dart';
import 'general_cloud.dart';

class AuthorityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ITCFirebaseLogic _firebaseLogic = ITCFirebaseLogic();


  // Get linked companies (already approved)
  Future<List<Company>> getLinkedCompaniesForAuthority(String authorityId) async {
    try {
      debugPrint("Getting linked companies for authority: $authorityId");

      final authorityDoc = await _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId)
          .get();

      if (!authorityDoc.exists) {
        print('Authority not found: $authorityId');
        return [];
      }

      final authority = Authority.fromMap(authorityDoc.data()! as Map<String, dynamic>);
      final linkedCompanyIds = authority.linkedCompanies;

      if (linkedCompanyIds.isEmpty) {
        print('No linked companies found for authority: ${authority.name}');
        return [];
      }

      final List<Company> companies = [];

      for (final companyId in linkedCompanyIds) {
        try {
          final company = await _firebaseLogic.getCompany(companyId);
          if (company != null) {
            companies.add(company);
          } else {
            print('Company not found or deleted: $companyId');
          }
        } catch (e) {
          print('Error fetching company $companyId: $e');
        }
      }

      print('Found ${companies.length} linked companies for authority ${authority.name}');
      return companies;

    } catch (e) {
      print('Error fetching linked companies: $e');
      rethrow;
    }
  }

  // Get pending companies (company IDs are directly in pendingApplications array)
  Future<List<Company>> getPendingCompaniesForAuthority(String authorityId) async {
    try {
      debugPrint("Getting pending companies for authority: $authorityId");

      final authorityDoc = await _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId)
          .get();

      if (!authorityDoc.exists) {
        print('Authority not found: $authorityId');
        return [];
      }

      final authority = Authority.fromMap(authorityDoc.data()! as Map<String, dynamic>);
      final pendingCompanyIds = authority.pendingApplications;

      if (pendingCompanyIds.isEmpty) {
        print('No pending companies found for authority: ${authority.name}');
        return [];
      }

      final List<Company> companies = [];

      for (final companyId in pendingCompanyIds) {
        try {
          final company = await _firebaseLogic.getCompany(companyId);
          if (company != null) {
            companies.add(company);
          } else {
            print('Company not found or deleted: $companyId');
          }
        } catch (e) {
          print('Error fetching company $companyId: $e');
        }
      }

      print('Found ${companies.length} pending companies for authority ${authority.name}');
      return companies;

    } catch (e) {
      print('Error fetching pending companies: $e');
      rethrow;
    }
  }

  // NEW: Simple approve method (moves company from pending to linked)
  Future<Map<String, dynamic>> approvePendingCompany({
    required String authorityId,
    required String companyId,
    String? remarks,
    String? approvedByUserId,
  }) async {
    try {
      final authorityRef = _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId);

      await _firestore.runTransaction((transaction) async {
        final authoritySnap = await transaction.get(authorityRef);
        if (!authoritySnap.exists) {
          throw Exception('Authority not found');
        }

        final authority = Authority.fromMap(authoritySnap.data()!);

        // Check if company is in pending applications
        if (!authority.pendingApplications.contains(companyId)) {
          throw Exception('Company not found in pending applications');
        }

        // Check if already linked
        if (authority.linkedCompanies.contains(companyId)) {
          throw Exception('Company already linked to this authority');
        }

        // Check authority limit
        if (authority.hasReachedCompanyLimit) {
          throw Exception('Authority has reached maximum company limit');
        }

        // Remove from pending, add to linked
        final updatedPendingApps =
        authority.pendingApplications.where((id) => id != companyId).toList();
        final updatedLinkedCompanies = [...authority.linkedCompanies, companyId];

        transaction.update(authorityRef, {
          'pendingApplications': updatedPendingApps,
          'linkedCompanies': updatedLinkedCompanies,
          'totalApplicationsReviewed': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Also update the company's authority status
      await _updateCompanyAuthorityStatus(
        companyId: companyId,
        authorityId: authorityId,
        status: 'APPROVED',
      );

      return {
        'success': true,
        'message': 'Company approved and linked successfully',
      };

    } catch (e) {
      print('Error approving pending company: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to approve company',
      };
    }
  }

  // NEW: Simple reject method (removes company from pending)
  Future<Map<String, dynamic>> rejectPendingCompany({
    required String authorityId,
    required String companyId,
    String? remarks,
    String? rejectedByUserId,
  }) async {
    try {
      final authorityRef = _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId);

      await _firestore.runTransaction((transaction) async {
        final authoritySnap = await transaction.get(authorityRef);
        if (!authoritySnap.exists) {
          throw Exception('Authority not found');
        }

        final authority = Authority.fromMap(authoritySnap.data()!);

        // Check if company is in pending applications
        if (!authority.pendingApplications.contains(companyId)) {
          throw Exception('Company not found in pending applications');
        }

        // Remove from pending
        final updatedPendingApps =
        authority.pendingApplications.where((id) => id != companyId).toList();

        transaction.update(authorityRef, {
          'pendingApplications': updatedPendingApps,
          'totalApplicationsReviewed': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Update company's authority status to rejected
      await _updateCompanyAuthorityStatus(
        companyId: companyId,
        authorityId: null,
        status: 'REJECTED',
      );

      return {
        'success': true,
        'message': 'Company request rejected',
      };

    } catch (e) {
      print('Error rejecting pending company: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to reject company',
      };
    }
  }

  // NEW: Update company's authority status
  Future<void> _updateCompanyAuthorityStatus({
    required String companyId,
    required String? authorityId,
    required String status,
  }) async {
    try {
      final companyRef = _firestore.collection("users").doc("companies").collection('companies').doc(companyId);

      final updateData = {
        'isUnderAuthority': authorityId != null,
        'authorityId': authorityId,
        'authorityLinkStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await companyRef.update(updateData);
    } catch (e) {
      print('Error updating company authority status: $e');
      // Don't rethrow - this is secondary to the main transaction
    }
  }



  // Alternative: Fetch companies in batches for better performance


  Future<List<Company>> getLinkedCompaniesForAuthorityBatched(String authorityId) async {
    try {
      // 1. Get authority document from updated path
      final authorityDoc = await _firestore
          .collection('users')
          .doc('authorities')
          .collection('authorities')
          .doc(authorityId)
          .get();

      if (!authorityDoc.exists) {
        return [];
      }

      final authority = Authority.fromMap(authorityDoc.data()! as Map<String, dynamic>);
      final linkedCompanyIds = authority.linkedCompanies;

      if (linkedCompanyIds.isEmpty) {
        return [];
      }

      // 2. Create batch query for better performance
      final List<Future<Company?>> companyFutures = [];

      for (final companyId in linkedCompanyIds) {
        companyFutures.add(_firebaseLogic.getCompany(companyId));
      }

      // 3. Wait for all futures to complete
      final List<Company?> companies = await Future.wait(companyFutures);

      // 4. Filter out null values (companies that weren't found)
      return companies
          .where((company) => company != null)
          .map((company) => company!)
          .toList();

    } catch (e) {
      print('Error in batched company fetch: $e');
      rethrow;
    }
  }

  // Method to stream linked companies (real-time updates)
  Stream<List<Company>> streamLinkedCompaniesForAuthority(String authorityId) {
    return _firestore
        .collection('users')
        .doc('authorities')
        .collection('authorities')
        .doc(authorityId)
        .snapshots()
        .asyncMap((authoritySnapshot) async {
      if (!authoritySnapshot.exists) {
        return [];
      }

      final authority = Authority.fromMap(
          authoritySnapshot.data()! as Map<String, dynamic>);
      final linkedCompanyIds = authority.linkedCompanies;

      if (linkedCompanyIds.isEmpty) {
        return [];
      }

      // Fetch companies for the current list of IDs
      final List<Company> companies = [];
      for (final companyId in linkedCompanyIds) {
        try {
          final company = await _firebaseLogic.getCompany(companyId);
          if (company != null) {
            companies.add(company);
          }
        } catch (e) {
          print('Error streaming company $companyId: $e');
        }
      }

      return companies;
    });
  }

  // NEW: Helper method to get authority document reference
  DocumentReference<Map<String, dynamic>> getAuthorityRef(String authorityId) {
    return _firestore
        .collection('users')
        .doc('authorities')
        .collection('authorities')
        .doc(authorityId);
  }

  // NEW: Get authority by ID
  Future<Authority?> getAuthorityById(String authorityId) async {
    try {
      final doc = await getAuthorityRef(authorityId).get();
      if (doc.exists) {
        return Authority.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting authority: $e');
      return null;
    }
  }

  // NEW: Stream authority (real-time)
  Stream<Authority?> streamAuthority(String authorityId) {
    return getAuthorityRef(authorityId)
        .snapshots()
        .map((snapshot) => snapshot.exists
        ? Authority.fromMap(snapshot.data()!)
        : null);
  }

  // NEW: Add company to authority's linked companies
  Future<bool> addCompanyToAuthority({
    required String authorityId,
    required String companyId,
  }) async {
    try {
      final authorityRef = getAuthorityRef(authorityId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(authorityRef);
        if (!snapshot.exists) {
          throw Exception('Authority not found');
        }

        final authority = Authority.fromMap(snapshot.data()!);
        if (authority.linkedCompanies.contains(companyId)) {
          throw Exception('Company already linked to this authority');
        }

        if (authority.hasReachedCompanyLimit) {
          throw Exception('Authority has reached maximum company limit');
        }

        final updatedLinkedCompanies = [...authority.linkedCompanies, companyId];
        transaction.update(authorityRef, {
          'linkedCompanies': updatedLinkedCompanies,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      print('Error adding company to authority: $e');
      return false;
    }
  }

  // NEW: Remove company from authority's linked companies
  Future<bool> removeCompanyFromAuthority({
    required String authorityId,
    required String companyId,
  }) async {
    try {
      final authorityRef = getAuthorityRef(authorityId);

      await unlinkCompanyFromAuthority(authorityId: authorityId, companyId: companyId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(authorityRef);
        if (!snapshot.exists) {
          throw Exception('Authority not found');
        }

        final authority = Authority.fromMap(snapshot.data()!);
        if (!authority.linkedCompanies.contains(companyId)) {
          throw Exception('Company not linked to this authority');
        }

        final updatedLinkedCompanies =
        authority.linkedCompanies.where((id) => id != companyId).toList();

        transaction.update(authorityRef, {
          'linkedCompanies': updatedLinkedCompanies,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });



      return true;
    } catch (e) {
      print('Error removing company from authority: $e');
      return false;
    }
  }

  // ============ UNLINK COMPANY WITH HISTORY TRACKING ============
  Future<Map<String, dynamic>> unlinkCompanyFromAuthority({
    required String authorityId,
    required String companyId,
    String? reason,
    String? unlinkedByUserId,
    String? unlinkedByUserName,
  }) async {
    try {
      debugPrint("Unlinking company $companyId from authority $authorityId");

      // Get authority and company references
      final authorityRef = getAuthorityRef(authorityId);
      final companyRef = _firestore.collection("users").doc("companies").collection('companies').doc(companyId);

      // Run in a transaction for data consistency
      await _firestore.runTransaction((transaction) async {
        // Get authority data
        final authoritySnap = await transaction.get(authorityRef);
        if (!authoritySnap.exists) {
          throw Exception('Authority not found');
        }

        final authority = Authority.fromMap(authoritySnap.data()!);

        // Get company data
        final companySnap = await transaction.get(companyRef);
        if (!companySnap.exists) {
          throw Exception('Company not found');
        }

        final company = Company.fromMap(companySnap.data()!);

        // Check if company is actually linked to this authority
        if (!authority.linkedCompanies.contains(companyId)) {
          throw Exception('Company is not linked to this authority');
        }

        if (company.authorityId != authorityId) {
          throw Exception('Company is linked to a different authority');
        }

        // =========== UPDATE AUTHORITY ===========
        // Remove from linked companies
        final updatedLinkedCompanies =
        authority.linkedCompanies.where((id) => id != companyId).toList();

        // Create unlink history entry
        final unlinkHistory = {
          'companyId': companyId,
          'companyName': company.name,
          'unlinkedAt': DateTime.now().toIso8601String(),
          'unlinkedBy': unlinkedByUserId,
          'unlinkedByName': unlinkedByUserName,
          'reason': reason,
        };

        // Add to unlinked history array
        final currentUnlinkedHistory = authority.unlinkedCompaniesHistory ?? [];
        final updatedUnlinkedHistory = [...currentUnlinkedHistory, unlinkHistory];

        transaction.update(authorityRef, {
          'linkedCompanies': updatedLinkedCompanies,
          'unlinkedCompaniesHistory': updatedUnlinkedHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // =========== UPDATE COMPANY ===========
        // Reset company to standalone but mark as "PREVIOUSLY_LINKED"
        // so the dialog will be shown
        transaction.update(companyRef, {
          'isUnderAuthority': false,
          'authorityId': null,
          'authorityName': null,
          'authorityLinkStatus': 'PREVIOUSLY_LINKED', // Special status for dialog
          'wasUnderAuthority': true, // Track that it was previously under authority
          'previousAuthorityId': authorityId,
          'previousAuthorityName': authority.name,
          'unlinkedAt': FieldValue.serverTimestamp(),
          'unlinkedBy': unlinkedByUserId,
          'unlinkedReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // =========== CREATE SEPARATE UNLINK RECORD ===========
      await _createUnlinkRecord(
        authorityId: authorityId,
        companyId: companyId,
        reason: reason,
        unlinkedByUserId: unlinkedByUserId,
        unlinkedByUserName: unlinkedByUserName,
      );

      // =========== SEND NOTIFICATION ===========
      await _sendUnlinkNotification(
        companyId: companyId,
        authorityId: authorityId,
        reason: reason,
      );

      return {
        'success': true,
        'message': 'Company successfully unlinked from authority',
        'data': {
          'authorityId': authorityId,
          'companyId': companyId,
          'shouldShowDialog': true, // Flag to show authority specification dialog
        }
      };

    } catch (e) {
      debugPrint('Error unlinking company: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to unlink company',
      };
    }
  }

  // ============ CREATE UNLINK RECORD (SEPARATE COLLECTION) ============
  Future<void> _createUnlinkRecord({
    required String authorityId,
    required String companyId,
    String? reason,
    String? unlinkedByUserId,
    String? unlinkedByUserName,
  }) async {
    try {
      final recordId = 'unlink_${companyId}_${authorityId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('authorityUnlinkRecords').doc(recordId).set({
        'recordId': recordId,
        'authorityId': authorityId,
        'companyId': companyId,
        'type': 'permanent_unlink',
        'unlinkedBy': unlinkedByUserId,
        'unlinkedByName': unlinkedByUserName,
        'reason': reason,
        'unlinkedAt': FieldValue.serverTimestamp(),
        'restored': false,
        'company': await _getCompanyBasicInfo(companyId),
        'authority': await _getAuthorityBasicInfo(authorityId),
      });
    } catch (e) {
      debugPrint('Error creating unlink record: $e');
    }
  }

  // ============ GET UNLINK HISTORY FOR AUTHORITY ============
  Future<List<Map<String, dynamic>>> getUnlinkHistoryForAuthority(String authorityId) async {
    try {
      final query = await _firestore
          .collection('authorityUnlinkRecords')
          .where('authorityId', isEqualTo: authorityId)
          .orderBy('unlinkedAt', descending: true)
          .limit(50) // Limit to prevent too many reads
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting unlink history: $e');
      return [];
    }
  }

  // ============ RESTORE UNLINKED COMPANY ============
  Future<Map<String, dynamic>> restoreUnlinkedCompany({
    required String authorityId,
    required String companyId,
    String? reason,
    String? restoredByUserId,
    String? restoredByUserName,
  }) async {
    try {
      final authorityRef = getAuthorityRef(authorityId);
      final companyRef = _firestore.collection("users").doc("companies").collection('companies').doc(companyId);

      await _firestore.runTransaction((transaction) async {
        final authoritySnap = await transaction.get(authorityRef);
        if (!authoritySnap.exists) {
          throw Exception('Authority not found');
        }

        final authority = Authority.fromMap(authoritySnap.data()!);

        // Check if company is already linked
        if (authority.linkedCompanies.contains(companyId)) {
          throw Exception('Company is already linked to this authority');
        }

        // Check authority limit
        if (authority.hasReachedCompanyLimit) {
          throw Exception('Authority has reached maximum company limit');
        }

        // Add back to linked companies
        final updatedLinkedCompanies = [...authority.linkedCompanies, companyId];

        transaction.update(authorityRef, {
          'linkedCompanies': updatedLinkedCompanies,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update company status
        transaction.update(companyRef, {
          'isUnderAuthority': true,
          'authorityId': authorityId,
          'authorityName': authority.name,
          'authorityLinkStatus': 'RESTORED',
          'restoredAt': FieldValue.serverTimestamp(),
          'restoredBy': restoredByUserId,
          'restoredReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Update unlink record
      await _updateUnlinkRecordAsRestored(companyId, authorityId);

      return {
        'success': true,
        'message': 'Company restored successfully',
      };

    } catch (e) {
      debugPrint('Error restoring company: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to restore company',
      };
    }
  }

  // ============ UPDATE COMPANY TO STANDALONE (NO DIALOG) ============
  Future<Map<String, dynamic>> setCompanyAsStandalone({
    required String companyId,
    String? reason,
    String? updatedByUserId,
  }) async {
    try {
      final companyRef = _firestore.collection("users").doc("companies").collection('companies').doc(companyId);

      await companyRef.update({
        'isUnderAuthority': false,
        'authorityId': null,
        'authorityName': null,
        'authorityLinkStatus': 'STANDALONE',
        'wasUnderAuthority': false,
        'previousAuthorityId': null,
        'previousAuthorityName': null,
        'standaloneSelectedAt': FieldValue.serverTimestamp(),
        'standaloneSelectedBy': updatedByUserId,
        'standaloneReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Company set as standalone',
      };

    } catch (e) {
      debugPrint('Error setting company as standalone: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to set company as standalone',
      };
    }
  }

  // ============ UPDATE COMPANY TO UNDER AUTHORITY (NO DIALOG) ============
  Future<Map<String, dynamic>> setCompanyAsUnderAuthority({
    required String companyId,
    required String authorityId,
    String? authorityName,
    String? reason,
    String? updatedByUserId,
  }) async {
    try {
      final companyRef = _firestore.collection("users").doc("companies").collection('companies').doc(companyId);

      await companyRef.update({
        'isUnderAuthority': true,
        'authorityId': authorityId,
        'authorityName': authorityName,
        'authorityLinkStatus': 'UNDER_AUTHORITY',
        'wasUnderAuthority': true,
        'underAuthoritySelectedAt': FieldValue.serverTimestamp(),
        'underAuthoritySelectedBy': updatedByUserId,
        'underAuthorityReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also add to authority's pending applications if not already
      final authorityRef = getAuthorityRef(authorityId);
      await _firestore.runTransaction((transaction) async {
        final authoritySnap = await transaction.get(authorityRef);
        if (authoritySnap.exists) {
          final authority = Authority.fromMap(authoritySnap.data()!);
          if (!authority.pendingApplications.contains(companyId) &&
              !authority.linkedCompanies.contains(companyId)) {
            final updatedPending = [...authority.pendingApplications, companyId];
            transaction.update(authorityRef, {
              'pendingApplications': updatedPending,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      return {
        'success': true,
        'message': 'Company set as under authority',
      };

    } catch (e) {
      debugPrint('Error setting company under authority: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to set company under authority',
      };
    }
  }

  // ============ CHECK IF COMPANY NEEDS AUTHORITY SPECIFICATION DIALOG ============
  Future<bool> needsAuthoritySpecificationDialog(String companyId) async {
    try {
      final company = await _firebaseLogic.getCompany(companyId);
      if (company == null) return false;

      // Show dialog if:
      // 1. Company is not under authority AND
      // 2. Authority link status is "PREVIOUSLY_LINKED" (after unlink) OR "NONE" (new company)
      return !company.isUnderAuthority &&
          (company.authorityLinkStatus == 'PREVIOUSLY_LINKED' ||
              company.authorityLinkStatus == 'NONE');
    } catch (e) {
      debugPrint('Error checking dialog need: $e');
      return false;
    }
  }

  // ============ HELPER METHODS ============

  Future<Map<String, dynamic>> _getCompanyBasicInfo(String companyId) async {
    try {
      final company = await _firebaseLogic.getCompany(companyId);
      if (company != null) {
        return {
          'id': company.id,
          'name': company.name,
          'industry': company.industry,
          'logoURL': company.logoURL,
        };
      }
    } catch (e) {
      debugPrint('Error getting company info: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> _getAuthorityBasicInfo(String authorityId) async {
    try {
      final authority = await getAuthorityById(authorityId);
      if (authority != null) {
        return {
          'id': authority.id,
          'name': authority.name,
          'logoURL': authority.logoURL,
        };
      }
    } catch (e) {
      debugPrint('Error getting authority info: $e');
    }
    return {};
  }

  Future<void> _updateUnlinkRecordAsRestored(String companyId, String authorityId) async {
    try {
      final query = await _firestore
          .collection('authorityUnlinkRecords')
          .where('authorityId', isEqualTo: authorityId)
          .where('companyId', isEqualTo: companyId)
          .where('restored', isEqualTo: false)
          .orderBy('unlinkedAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'restored': true,
          'restoredAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating unlink record: $e');
    }
  }

  Future<void> _sendUnlinkNotification({
    required String companyId,
    required String authorityId,
    String? reason,
  }) async {
    try {
      final company = await _firebaseLogic.getCompany(companyId);
      final authority = await getAuthorityById(authorityId);

      if (company != null && authority != null) {
        // Create in-app notification for company
        await _firestore.collection('notifications').add({
          'userId': companyId,
          'userType': 'company',
          'title': 'Unlinked from Authority',
          'message': 'Your company has been unlinked from ${authority.name}',
          'type': 'authority_unlink',
          'data': {
            'authorityId': authorityId,
            'authorityName': authority.name,
            'companyId': companyId,
            'reason': reason,
            'timestamp': DateTime.now().toIso8601String(),
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Also create notification for authority admins
        for (final adminId in authority.admins) {
          await _firestore.collection('notifications').add({
            'userId': adminId,
            'userType': 'admin',
            'title': 'Company Unlinked',
            'message': '${company.name} has been unlinked from your authority',
            'type': 'company_unlinked',
            'data': {
              'authorityId': authorityId,
              'authorityName': authority.name,
              'companyId': companyId,
              'companyName': company.name,
              'reason': reason,
              'timestamp': DateTime.now().toIso8601String(),
            },
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error sending unlink notification: $e');
    }
  }

  // ============ GET ALL UNLINKED COMPANIES FOR AUTHORITY ============
  Future<List<Map<String, dynamic>>> getUnlinkedCompaniesForAuthority(String authorityId) async {
    try {
      final history = await getUnlinkHistoryForAuthority(authorityId);

      final List<Map<String, dynamic>> companies = [];

      for (final record in history) {
        final companyId = record['companyId'];
        if (companyId != null) {
          try {
            final company = await _firebaseLogic.getCompany(companyId);
            if (company != null) {
              companies.add({
                ...record,
                'company': company.toMap(),
              });
            }
          } catch (e) {
            debugPrint('Error fetching company $companyId: $e');
          }
        }
      }

      return companies;
    } catch (e) {
      debugPrint('Error getting unlinked companies: $e');
      return [];
    }
  }

  // ============ GET COMPANY'S AUTHORITY HISTORY ============
  Future<List<Map<String, dynamic>>> getCompanyAuthorityHistory(String companyId) async {
    try {
      final query = await _firestore
          .collection('authorityUnlinkRecords')
          .where('companyId', isEqualTo: companyId)
          .orderBy('unlinkedAt', descending: true)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting company authority history: $e');
      return [];
    }
  }
}