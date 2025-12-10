import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import '../../model/applicationNotification.dart';
import '../../model/company.dart';
import '../../model/internship_model.dart';

class Student_cloud_db {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Fetch featured companies from: users/companies/companies
  Stream<List<Company>> getAllCompanies() {
    return _firebaseFirestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Company company = Company.fromMap(
              doc.data() as Map<String, dynamic>,
            );
            return company;
          }).toList();
        });
  }

  Stream<Map<String, int>> statsStream(String userId) {
    final appsStream = _firebaseFirestore
        .collection('users')
        .doc('companies')
        .collection('companies')
        .snapshots()
        .asyncMap((companySnapshot) async {
          List<QueryDocumentSnapshot<Map<String, dynamic>>> allAppDocs = [];

          for (var companyDoc in companySnapshot.docs) {
            final internshipsSnapshot = await _firebaseFirestore
                .collection('users')
                .doc('companies')
                .collection('companies')
                .doc(companyDoc.data()['id'])
                .collection('IT')
                .get();
            for (var internshipDoc in internshipsSnapshot.docs) {
              final applicationsSnapshot = await _firebaseFirestore
                  .collection('users')
                  .doc('companies')
                  .collection('companies')
                  .doc(companyDoc.data()['id'])
                  .collection('IT')
                  .doc(internshipDoc.id)
                  .collection('applications')
                  .where('uid', isEqualTo: userId)
                  .get();

              allAppDocs.addAll(applicationsSnapshot.docs);
            }
          }

          return allAppDocs;
        });

    final bookingsStream = _firebaseFirestore
        .collection('users')
        .doc('landlords')
        .collection('landlords')
        .snapshots()
        .asyncMap((landlordSnapshot) async {
          List<Map<String, dynamic>> allBookingDocs = [];

          for (var landlordDoc in landlordSnapshot.docs) {
            final accommodationsSnapshot = await _firebaseFirestore
                .collection('users')
                .doc('landlords')
                .collection('landlords')
                .doc(landlordDoc.id)
                .collection('accommodations')
                .get();

            for (var accomDoc in accommodationsSnapshot.docs) {
              final accommodationData = accomDoc.data();

              final bookingRequestsMap =
                  accommodationData['bookingRequests'] as Map<String, dynamic>?;

              if (bookingRequestsMap != null) {
                bookingRequestsMap.forEach((studentId, bookingData) {
                  if (bookingData is Map<String, dynamic> &&
                      studentId == userId) {
                    allBookingDocs.add(bookingData);
                  }
                });
              }
            }
          }

          return allBookingDocs;
        });

    final sentMessagesStream = _firebaseFirestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatRoomsSnapshot) async {
          int totalSent = 0;
          for (var doc in chatRoomsSnapshot.docs) {
            final snapshot = await _firebaseFirestore
                .collection('chat_rooms')
                .doc(doc.id)
                .collection('messages')
                .where('sender_id', isEqualTo: userId)
                .get();

            totalSent += snapshot.size;
          }

          return totalSent;
        });

    final unreadMessagesStream = _firebaseFirestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((chatRoomsSnapshot) async {
          int totalUnread = 0;
          for (var doc in chatRoomsSnapshot.docs) {
            final snapshot = await _firebaseFirestore
                .collection('chat_rooms')
                .doc(doc.id)
                .collection('messages')
                .where('receiver_id', isEqualTo: userId)
                .where('is_read', isEqualTo: false)
                .get();
            totalUnread += snapshot.size;
          }

          return totalUnread;
        });

    final savedStream = _firebaseFirestore
        .collection('users')
        .doc('students')
        .collection('students')
        .doc(userId)
        .collection('saved_internships')
        .snapshots()
        .map((snap) => snap.size);

    //to combine multiple asynchronous data streams and compute a summary result.
    return Rx.combineLatest5<
      List<QueryDocumentSnapshot<Map<String, dynamic>>>,
      List<Map<String, dynamic>>,
      int,
      int,
      int,
      Map<String, int>
    >(
      appsStream,
      bookingsStream,
      sentMessagesStream,
      unreadMessagesStream,
      savedStream,
      (apps, bookings, sentCount, unreadCount, savedCount) {
        int accepted = 0;
        int rejected = 0;
        int pending = 0;

        for (var doc in apps) {
          final status = doc.data()['applicationStatus'] as String?;
          if (status?.trim() == 'accepted') {
            accepted++;
          } else if (status?.trim() == 'rejected') {
            rejected++;
          } else {
            pending++;
          }
        }

        return {
          'totalApplications': apps.length,
          'accepted': accepted,
          'rejected': rejected,
          'pending': pending,
          'bookings': bookings.length,
          'messages': sentCount,
          'unreadMessages': unreadCount,
          'saved': savedCount,
        };
      },
    );
  }

  /// Updates the student's profile image URL
  Future<void> updateStudentProfileImage({
    required String studentId,
    required String imageUrl,
  }) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(studentId)
          .update({'imageUrl': imageUrl});
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the student's portfolio fields
  Future<void> updateStudentPortfolio({
    required String studentId,
    required Map<String, dynamic> portfolioFields,
  }) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc('students')
          .collection('students')
          .doc(studentId)
          .update(portfolioFields);
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<AppNotification>> notificationStream(String studentUid) {
    return _firebaseFirestore
        .collection('users')
        .doc('students')
        .collection('students')
        .doc(studentUid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs.map((doc) {
            final data = doc.data();
            return AppNotification(
              title: data['status'] ?? 'No Title',
              body: data['message'] ?? 'No Message',
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();
        });
  }

  Future<List<IndustrialTraining>> savedIT() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snapShot = await FirebaseFirestore.instance
        .collection('users')
        .doc('students')
        .collection('students')
        .doc(user.uid)
        .collection('saved_internships')
        .get();

    return snapShot.docs.map((doc) {
      return IndustrialTraining.fromMap(doc.data(), doc.id);
    }).toList();
  }
}
