// lib/features/admin/services/agreement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AgreementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if company has signed agreement
  Future<bool> hasSignedAgreement(String companyId) async {
    try {
      final doc = await _firestore
          .collection('company_partnerships')
          .doc(companyId) // Using companyId as document ID
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['agreementSigned'] == true && data?['status'] == 'active';
      }
      return false;
    } catch (e) {
      print('Error checking agreement: $e');
      return false;
    }
  }

  // Alternative: Check using query if using generated IDs
  Future<bool> hasSignedAgreementByQuery(String companyId) async {
    try {
      final query = await _firestore
          .collection('company_partnerships')
          .where('companyId', isEqualTo: companyId)
          .where('agreementSigned', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking agreement: $e');
      return false;
    }
  }

  // Get full agreement details
  Future<Map<String, dynamic>?> getAgreementDetails(String companyId) async {
    try {
      final doc = await _firestore
          .collection('company_partnerships')
          .doc(companyId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting agreement details: $e');
      return null;
    }
  }
}