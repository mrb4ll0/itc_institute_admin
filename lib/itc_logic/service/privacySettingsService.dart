// services/privacy_settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../model/privacySettingModel.dart';


class PrivacySettingsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'privacy_settings';

  // Get user's privacy settings
  static Future<PrivacySettings> getUserPrivacySettings(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        return PrivacySettings.fromFirestore(doc);
      } else {
        // Create default settings for new user
        final defaultSettings = PrivacySettings.defaultSettings();
        await savePrivacySettings(userId, defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      print('Error getting privacy settings: $e');
      return PrivacySettings.defaultSettings();
    }
  }

  // Save privacy settings
  static Future<void> savePrivacySettings(String userId, PrivacySettings settings) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      await docRef.set(settings.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving privacy settings: $e');
      rethrow;
    }
  }

  // Update specific privacy setting
  static Future<void> updatePrivacySetting(
      String userId,
      String field,
      dynamic value,
      ) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      await docRef.update({
        field: value,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      print('Error updating privacy setting: $e');
      rethrow;
    }
  }

  // Get privacy settings for multiple users (for displaying to other users)
  static Future<Map<String, PrivacySettings>> getMultipleUsersPrivacySettings(
      List<String> userIds,
      ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      final Map<String, PrivacySettings> settings = {};
      for (final doc in querySnapshot.docs) {
        settings[doc.id] = PrivacySettings.fromFirestore(doc);
      }

      // Add default settings for users without documents
      for (final userId in userIds) {
        if (!settings.containsKey(userId)) {
          settings[userId] = PrivacySettings.defaultSettings();
        }
      }

      return settings;
    } catch (e) {
      print('Error getting multiple privacy settings: $e');
      return {};
    }
  }

  // Check if a user can view another user's profile
  static Future<bool> canViewProfile(
      String viewerUserId,
      String targetUserId,
      ) async {
    if (viewerUserId == targetUserId) return true;

    final targetSettings = await getUserPrivacySettings(targetUserId);

    if (!targetSettings.profileVisibility) {
      return false;
    }

    // Add additional logic here for blocked users, etc.
    return true;
  }

  // Check if a user can see another user's email
  static Future<bool> canViewEmail(
      String viewerUserId,
      String targetUserId,
      ) async {
    if (viewerUserId == targetUserId) return true;

    final targetSettings = await getUserPrivacySettings(targetUserId);

    if (!targetSettings.showEmail) {
      return false;
    }

    return true;
  }

  // Check if a user can see another user's phone number
  static Future<bool> canViewPhoneNumber(
      String viewerUserId,
      String targetUserId,
      ) async {
    if (viewerUserId == targetUserId) return true;

    final targetSettings = await getUserPrivacySettings(targetUserId);

    if (!targetSettings.showPhoneNumber) {
      return false;
    }

    return true;
  }

  // Get user's online status visibility
  static Future<bool> canSeeOnlineStatus(
      String viewerUserId,
      String targetUserId,
      ) async {
    if (viewerUserId == targetUserId) return true;

    final targetSettings = await getUserPrivacySettings(targetUserId);

    return targetSettings.showOnlineStatus;
  }

  // Get user's last seen visibility
  static Future<bool> canSeeLastSeen(
      String viewerUserId,
      String targetUserId,
      ) async {
    if (viewerUserId == targetUserId) return true;

    final targetSettings = await getUserPrivacySettings(targetUserId);

    return targetSettings.showLastSeen;
  }

  // Stream privacy settings for real-time updates
  static Stream<PrivacySettings> streamPrivacySettings(String userId) {
    return _firestore
        .collection(_collectionName)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return PrivacySettings.fromFirestore(doc);
      } else {
        return PrivacySettings.defaultSettings();
      }
    });
  }

  // Reset privacy settings to default
  static Future<void> resetPrivacySettings(String userId) async {
    try {
      final defaultSettings = PrivacySettings.defaultSettings();
      await savePrivacySettings(userId, defaultSettings);
    } catch (e) {
      print('Error resetting privacy settings: $e');
      rethrow;
    }
  }

  // Delete privacy settings (when user deletes account)
  static Future<void> deletePrivacySettings(String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).delete();
    } catch (e) {
      print('Error deleting privacy settings: $e');
      rethrow;
    }
  }
}