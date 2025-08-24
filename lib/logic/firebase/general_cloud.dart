import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/institution_model.dart';

class InstitutionService {
  final CollectionReference _institutionRef =
  FirebaseFirestore.instance.collection('institutions');

  /// Add a new Institution with the current user's UID as the docId
  Future<String> addInstitution(Institution institution) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("No authenticated user found");
    }

    final docRef = _institutionRef.doc(user.uid);

    final newInstitution = Institution(
      institutionCode: institution.institutionCode,
      id: user.uid,
      name: institution.name,
      shortName: institution.shortName,
      type: institution.type,
      address: institution.address,
      city: institution.city,
      state: institution.state,
      country: institution.country,
      localGovernment: institution.localGovernment,
      contactEmail: institution.contactEmail,
      contactPhone: institution.contactPhone,
      website: institution.website,
      logoUrl: institution.logoUrl,
      accreditationStatus: institution.accreditationStatus,
      establishedYear: institution.establishedYear,
      faculties: institution.faculties,
      departments: institution.departments,
      programsOffered: institution.programsOffered,
      admissionRequirements: institution.admissionRequirements,
      isActive: institution.isActive,
      createdAt: institution.createdAt,
      updatedAt: institution.updatedAt,
    );

    await docRef.set(newInstitution.toMap());

    return user.uid; // return the Auth UID as the docId
  }

  /// Get Institution by Firestore docId (usually = user.uid)
  Future<Institution?> getInstitutionById(String id) async {
    final doc = await _institutionRef.doc(id).get();
    if (doc.exists) {
      return Institution.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  /// Update institution (docId = institution.id)
  Future<void> updateInstitution(Institution institution) async {
    await _institutionRef.doc(institution.id).update(institution.toMap());
  }

  /// Delete institution
  Future<void> deleteInstitution(String id) async {
    await _institutionRef.doc(id).delete();
  }

  Future<Institution?> verifyInstitutionCode(String enteredCode) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null; // no user logged in
      }

      // Reference to institution doc using UID
      final doc = await FirebaseFirestore.instance
          .collection('institutions')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        return null; // institution not found
      }

      // Get stored institution code
      final storedCode = doc.data()?['institutionCode'] as String?;

      if (storedCode == null) {
        return null; // no code in db
      }

      // Compare codes
      if(storedCode.trim() == enteredCode.trim() && doc.data() != null)
      {
        return Institution.fromMap(doc.data()!);
      }
    } catch (e) {
      print("Error verifying institution code: $e");
      return null;
    }
  }
}
