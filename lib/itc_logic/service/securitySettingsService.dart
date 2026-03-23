// services/security_settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../model/securitySettingsModel.dart';


class SecuritySettingsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'security_settings';

  // Get user's security settings
  static Future<SecuritySettings> getUserSecuritySettings(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        return SecuritySettings.fromFirestore(doc);
      } else {
        // Create default settings for new user
        final defaultSettings = SecuritySettings.defaultSettings();
        await saveSecuritySettings(userId, defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      print('Error getting security settings: $e');
      return SecuritySettings.defaultSettings();
    }
  }

  // Save security settings
  static Future<void> saveSecuritySettings(String userId, SecuritySettings settings) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      await docRef.set(settings.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      print('Error saving security settings: $e');
      rethrow;
    }
  }

  // Update specific security setting
  static Future<void> updateSecuritySetting(
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
      print('Error updating security setting: $e');
      rethrow;
    }
  }

  // Record failed login attempt
  static Future<void> recordFailedLoginAttempt(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      await docRef.update({
        'failedLoginCount': FieldValue.increment(1),
        'lastFailedLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error recording failed login: $e');
    }
  }

  // Reset failed login attempts
  static Future<void> resetFailedLoginAttempts(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      await docRef.update({
        'failedLoginCount': 0,
      });
    } catch (e) {
      print('Error resetting failed attempts: $e');
    }
  }

  // Check if account is locked
  static Future<bool> isAccountLocked(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final settings = SecuritySettings.fromFirestore(doc);

        if (settings.lockAfterFailedAttempts) {
          final failedCount = data['failedLoginCount'] ?? 0;
          if (failedCount >= settings.maxFailedAttempts) {
            final lastFailed = (data['lastFailedLogin'] as Timestamp?)?.toDate();
            if (lastFailed != null) {
              final lockedUntil = lastFailed.add(Duration(minutes: settings.lockDurationMinutes));
              if (DateTime.now().isBefore(lockedUntil)) {
                return true;
              } else {
                await resetFailedLoginAttempts(userId);
              }
            }
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking account lock: $e');
      return false;
    }
  }

  // Stream security settings for real-time updates
  static Stream<SecuritySettings> streamSecuritySettings(String userId) {
    return _firestore
        .collection(_collectionName)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return SecuritySettings.fromFirestore(doc);
      } else {
        return SecuritySettings.defaultSettings();
      }
    });
  }

  // Reset security settings to default
  static Future<void> resetSecuritySettings(String userId) async {
    try {
      final defaultSettings = SecuritySettings.defaultSettings();
      await saveSecuritySettings(userId, defaultSettings);
    } catch (e) {
      print('Error resetting security settings: $e');
      rethrow;
    }
  }

  // Get active sessions for user
  static Stream<List<Map<String, dynamic>>> getActiveSessions(String userId) {
    return _firestore
        .collection('sessions')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'sessionId': doc.id,
          'deviceName': data['deviceName'],
          'deviceType': data['deviceType'],
          'ipAddress': data['ipAddress'],
          'location': data['location'],
          'lastActivity': (data['lastActivity'] as Timestamp).toDate(),
          'loginTime': (data['loginTime'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  // Terminate a specific session
  static Future<void> terminateSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'isActive': false,
        'terminatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error terminating session: $e');
      rethrow;
    }
  }

  // Terminate all other sessions
  static Future<void> terminateAllOtherSessions(String userId, String currentSessionId) async {
    try {
      final querySnapshot = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        if (doc.id != currentSessionId) {
          batch.update(doc.reference, {
            'isActive': false,
            'terminatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error terminating sessions: $e');
      rethrow;
    }
  }

  // Get password history
  static Future<List<String>> getPasswordHistory(String userId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['passwordHistory'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting password history: $e');
      return [];
    }
  }

  // Add password to history
  static Future<void> addToPasswordHistory(String userId, String passwordHash) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(userId);
      final settings = await getUserSecuritySettings(userId);

      final history = await getPasswordHistory(userId);
      history.insert(0, passwordHash);

      // Keep only the last N passwords
      if (history.length > settings.passwordHistoryCount) {
        history.removeRange(settings.passwordHistoryCount, history.length);
      }

      await docRef.update({
        'passwordHistory': history,
      });
    } catch (e) {
      print('Error adding to password history: $e');
    }
  }

  // Check if password was used before
  static Future<bool> isPasswordReused(String userId, String passwordHash) async {
    try {
      final history = await getPasswordHistory(userId);
      return history.contains(passwordHash);
    } catch (e) {
      print('Error checking password reuse: $e');
      return false;
    }
  }
}