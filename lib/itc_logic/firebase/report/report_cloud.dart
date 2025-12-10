import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService
{
  Future<void> sendReport({
    required String type,
    required String message,
    String? reportedUserId,
  }) async {
    final reporterId = FirebaseAuth.instance.currentUser?.uid;

    if (reporterId == null) {
      throw Exception("User not logged in.");
    }

    final reportData = {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'type': type,
      'message': message,
      'reportedAt': Timestamp.now(), // ✅ match the fetch field name
      'status': 'new',               // ✅ match the fetch status filter
    };

    await FirebaseFirestore.instance.collection('reports').add(reportData);
  }


}