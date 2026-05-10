import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the correct collection path based on user type
  String _getUserCollectionPath(String userId) {
    // Check if user is admin (admin/id format)
    if (userId.startsWith('admin_') || userId.contains('admin')) {
      return 'admin';
    }

    // For other user types, we need to check the actual collection
    // This will be determined when updating counts
    return 'users'; // Fallback
  }

  // Get the specific document reference for a user
  Future<DocumentReference> _getUserRef(String userId) async {
    // Check if it's an admin
    if (userId.startsWith('admin_')) {
      return _firestore.collection('admin').doc(userId);
    }

    // Try to find user in different collections
    final studentDoc = await _firestore
        .collection('users/students/students')
        .doc(userId)
        .get();
    if (studentDoc.exists) {
      return _firestore.collection('users/students/students').doc(userId);
    }

    final companyDoc = await _firestore
        .collection('users/companies/companies')
        .doc(userId)
        .get();
    if (companyDoc.exists) {
      return _firestore.collection('users/companies/companies').doc(userId);
    }

    final authorityDoc = await _firestore
        .collection('users/authorities/authorities')
        .doc(userId)
        .get();
    if (authorityDoc.exists) {
      return _firestore.collection('users/authorities/authorities').doc(userId);
    }

    // Default to students collection
    return _firestore.collection('users/students/students').doc(userId);
  }

  // Get user type for display/storage
  Future<String?> getUserType(String userId) async {
    if (userId.startsWith('admin_')) {
      return 'admin';
    }

    final studentDoc = await _firestore
        .collection('users/students/students')
        .doc(userId)
        .get();
    if (studentDoc.exists) return 'student';

    final companyDoc = await _firestore
        .collection('users/companies/companies')
        .doc(userId)
        .get();
    if (companyDoc.exists) return 'company';

    final authorityDoc = await _firestore
        .collection('users/authorities/authorities')
        .doc(userId)
        .get();
    if (authorityDoc.exists) return 'authority';

    return null;
  }

  // Follow a user
  Future<void> followUser(String followerId, String followingId) async {
    final followDoc =
    _firestore.collection('follows').doc('${followerId}_$followingId');

    // Get user types for the follow relationship
    final followerType = await getUserType(followerId);
    final followingType = await getUserType(followingId);

    await followDoc.set({
      'followerId': followerId,
      'followerType': followerType,
      'followingId': followingId,
      'followingType': followingType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update counts
    await _updateFollowCounts(followerId, followingId, true);
  }

  // Unfollow a user
  Future<void> unfollowUser(String followerId, String followingId) async {
    final followDoc =
    _firestore.collection('follows').doc('${followerId}_$followingId');

    await followDoc.delete();

    // Update counts
    await _updateFollowCounts(followerId, followingId, false);
  }

  // Check if user is following another user
  Future<bool> isFollowing(String followerId, String followingId) async {
    final followDoc = await _firestore
        .collection('follows')
        .doc('${followerId}_$followingId')
        .get();

    return followDoc.exists;
  }

  // Get followers count for a user
  Future<int> getFollowersCount(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  // Get following count for a user
  Future<int> getFollowingCount(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  // Update follow counts in user document
  Future<void> _updateFollowCounts(
      String followerId, String followingId, bool isFollow) async {
    final batch = _firestore.batch();

    // Get references to both users in their respective collections
    if (followerId.contains('admin_')) {
      followerId = followerId.replaceAll('admin_', '');
    }
    if (followingId.contains('admin_')) {
      followingId = followingId.replaceAll('admin_', '');
    }
    final followerRef = await _getUserRef(followerId);
    final followingRef = await _getUserRef(followingId);

    if (isFollow) {
      batch.update(followerRef, {
        'followingCount': FieldValue.increment(1),
      });
      batch.update(followingRef, {
        'followersCount': FieldValue.increment(1),
      });
    } else {
      batch.update(followerRef, {
        'followingCount': FieldValue.increment(-1),
      });
      batch.update(followingRef, {
        'followersCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  // Get list of users that a user is following
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final followingList = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final followingId = doc['followingId'] as String;
      final followingType = doc['followingType'] as String?;

      // Fetch user details based on type
      final userData = await _getUserData(followingId, followingType);
      if (userData != null) {
        followingList.add({
          'userId': followingId,
          'userType': followingType,
          'userData': userData,
          'followedAt': doc['createdAt'],
        });
      }
    }

    return followingList;
  }

  // Get list of followers for a user
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final followersList = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final followerId = doc['followerId'] as String;
      final followerType = doc['followerType'] as String?;

      // Fetch user details based on type
      final userData = await _getUserData(followerId, followerType);
      if (userData != null) {
        followersList.add({
          'userId': followerId,
          'userType': followerType,
          'userData': userData,
          'followedAt': doc['createdAt'],
        });
      }
    }

    return followersList;
  }

  // Get user data from appropriate collection
  Future<Map<String, dynamic>?> _getUserData(
      String userId, String? userType) async {
    try {
      DocumentSnapshot userDoc;

      if (userId.startsWith('admin_') || userType == 'admin') {
        userDoc = await _firestore.collection('admin').doc(userId).get();
      } else if (userType == 'company') {
        userDoc = await _firestore
            .collection('users/companies/companies')
            .doc(userId)
            .get();
      } else if (userType == 'authority') {
        userDoc = await _firestore
            .collection('users/authorities/authorities')
            .doc(userId)
            .get();
      } else {
        // Default to student
        userDoc = await _firestore
            .collection('users/students/students')
            .doc(userId)
            .get();
      }

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting user data for $userId: $e');
    }
    return null;
  }

  // Get just the IDs of users that a user is following (for performance)
  Future<List<String>> getFollowingIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => doc['followingId'] as String).toList();
  }

  // Get just the IDs of followers for a user (for performance)
  Future<List<String>> getFollowersIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => doc['followerId'] as String).toList();
  }

  // Check if two users follow each other
  Future<bool> areMutualFollowers(String userId1, String userId2) async {
    final [follow1, follow2] = await Future.wait([
      isFollowing(userId1, userId2),
      isFollowing(userId2, userId1),
    ]);

    return follow1 && follow2;
  }

  // Get follow status for multiple users at once (batch check)
  Future<Map<String, bool>> getBulkFollowStatus(
      String currentUserId, List<String> userIds) async {
    final Map<String, bool> statusMap = {};

    for (final userId in userIds) {
      statusMap[userId] = await isFollowing(currentUserId, userId);
    }

    return statusMap;
  }
}
