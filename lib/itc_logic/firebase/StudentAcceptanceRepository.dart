import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

import '../../model/AuthorityRule.dart';

class StudentAcceptanceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save or update a student acceptance rule
  Future<void> saveRule(AuthorityRule rule) async {
    final docRef = _firestore
        .collection('authorityRules')
        .doc(rule.id); // Use fixed id per authority

    await docRef.set(rule.toMap(), SetOptions(merge: true));
  }

  /// Fetch rule for a specific authority
  Future<AuthorityRule?> fetchRule(String authorityId) async {
    debugPrint("authorityid $authorityId");
    final snapshot = await _firestore
        .collection('authorityRules')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: authorityId)
        .where(FieldPath.documentId, isLessThan: authorityId + '\uf8ff') // ensures prefix match
        .orderBy(FieldPath.documentId, descending: true) // latest first by timestamp
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      debugPrint("snapshot for rule is null");
      return null;
    }

    final data = snapshot.docs.first.data();
    return AuthorityRule.fromMap(data);
  }

}
