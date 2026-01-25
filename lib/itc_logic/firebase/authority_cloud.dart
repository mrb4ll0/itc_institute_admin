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
      final companyRef = _firestore.collection('companies').doc(companyId);

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
}