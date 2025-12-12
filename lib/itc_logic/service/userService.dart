import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../model/company.dart';
import '../../model/student.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<dynamic> getUserDetails(String userId) async {
    try {
      // Try to get student first
      final studentDoc = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(userId)
          .get();

      if (studentDoc.exists) {
        return Student.fromFirestore(studentDoc.data()!, userId);
      }

      // Try to get company
      final companyDoc = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(userId)
          .get();

      if (companyDoc.exists) {
        return Company.fromMap(companyDoc.data()!);
      }

      // Try in general users collection as fallback
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final role = data['role'] as String?;

        if (role == 'student') {
          return Student.fromFirestore(data, userId);
        } else if (role == 'company') {
          return Company.fromMap(data);
        }
      }

      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Check in students collection
      final studentDoc = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(user.uid)
          .get();

      if (studentDoc.exists) {
        return studentDoc.data();
      }

      // Check in companies collection
      final companyDoc = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(user.uid)
          .get();

      if (companyDoc.exists) {
        return companyDoc.data();
      }

      // Check in general users collection
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        return userDoc.data();
      }

      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  Future<String?> getCurrentUserRole() async {
    try {
      final data = await getCurrentUserData();
      return data?['role'] as String?;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  Future<Student?> getStudent(String userId) async {
    try {
      final studentDoc = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(userId)
          .get();

      if (studentDoc.exists) {
        return Student.fromFirestore(studentDoc.data()!, userId);
      }
      return null;
    } catch (e) {
      print('Error getting student: $e');
      return null;
    }
  }

  Future<Company?> getCompany(String userId) async {
    try {
      final companyDoc = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(userId)
          .get();

      if (companyDoc.exists) {
        return Company.fromMap(companyDoc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting company: $e');
      return null;
    }
  }

  Future<List<String>> getUserChatContacts(String userId) async {
    try {
      // Get all chat rooms where user is a participant
      final chatRooms = await _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: userId)
          .get();

      final List<String> contacts = [];

      for (final doc in chatRooms.docs) {
        final participants = (doc.data()['participants'] as List)
            .cast<String>();
        final otherUserId = participants.firstWhere(
          (id) => id != userId,
          orElse: () => '',
        );
        if (otherUserId.isNotEmpty) {
          contacts.add(otherUserId);
        }
      }

      return contacts;
    } catch (e) {
      print('Error getting user chat contacts: $e');
      return [];
    }
  }

  Future<void> updateUserFCMToken(String userId, String token) async {
    try {
      // Try to update in students collection
      await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(userId)
          .set({
            'fcmToken': token,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also try in companies collection
      await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(userId)
          .set({
            'fcmToken': token,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // And in general users collection
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  Future<String?> getUserFCMToken(String userId) async {
    try {
      final studentDoc = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(userId)
          .get();

      if (studentDoc.exists) {
        return studentDoc.data()?['fcmToken'] as String?;
      }

      final companyDoc = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .doc(userId)
          .get();

      if (companyDoc.exists) {
        return companyDoc.data()?['fcmToken'] as String?;
      }

      return null;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final List<Map<String, dynamic>> results = [];

      if (query.isEmpty) return results;

      // Search in students
      final studentsQuery = await _firestore
          .collection('users')
          .doc('students')
          .collection('students')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThan: query + 'z')
          .limit(10)
          .get();

      for (final doc in studentsQuery.docs) {
        results.add({...doc.data(), 'id': doc.id, 'type': 'student'});
      }

      // Search in companies
      final companiesQuery = await _firestore
          .collection('users')
          .doc('companies')
          .collection('companies')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .limit(10)
          .get();

      for (final doc in companiesQuery.docs) {
        results.add({...doc.data(), 'id': doc.id, 'type': 'company'});
      }

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<bool> isUserOnline(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('user_status')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final lastSeen = (data['lastSeen'] as Timestamp).toDate();
        final now = DateTime.now();
        final difference = now.difference(lastSeen).inMinutes;

        // Consider user online if they were active in the last 5 minutes
        return difference <= 5;
      }
      return false;
    } catch (e) {
      print('Error checking user online status: $e');
      return false;
    }
  }

  Future<void> updateUserLastSeen(String userId) async {
    try {
      await _firestore.collection('user_status').doc(userId).set({
        'lastSeen': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user last seen: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    return _firestore.collection('user_status').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        return {'online': false, 'lastSeen': null};
      }

      final data = snapshot.data()!;
      final lastSeen = (data['lastSeen'] as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(lastSeen).inMinutes;

      return {
        'online': difference <= 5,
        'lastSeen': lastSeen,
        'userId': userId,
      };
    });
  }
}
