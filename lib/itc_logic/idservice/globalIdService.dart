import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalIdService {
  static final GlobalIdService _instance = GlobalIdService._internal();
  factory GlobalIdService() => _instance;
  GlobalIdService._internal();

  static String? _currentFirestoreId;
  static String? _currentAuthUid;
  static String? _currentUserType; // 'company', 'authority', or null
  static bool _isInitialized = false;

  /// Initialize the service - call this once at app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final auth = FirebaseAuth.instance.currentUser;
    if (auth != null) {
      _currentAuthUid = auth.uid;
      await _resolveFirestoreId();
      _isInitialized = true;
    }
  }

  static Future<void> _resolveFirestoreId() async {
    // Try to get from auth_mappings first
    final mappingDoc = await FirebaseFirestore.instance
        .collection('auth_mappings')
        .doc(_currentAuthUid)
        .get();

    if (mappingDoc.exists) {
      final data = mappingDoc.data();
      _currentFirestoreId = data?['firestoreId'] as String?;
      _currentUserType = data?['userType'] as String?;
      return;
    }

    // Fallback: Check companies collection
    final companyQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc('companies')
        .collection('companies')
        .where('authUid', isEqualTo: _currentAuthUid)
        .limit(1)
        .get();

    if (companyQuery.docs.isNotEmpty) {
      final doc = companyQuery.docs.first;
      _currentFirestoreId = doc.id;
      _currentUserType = 'company';
      return;
    }

    // Fallback: Check authorities collection
    final authorityQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc('authorities')
        .collection('authorities')
        .where('authUid', isEqualTo: _currentAuthUid)
        .limit(1)
        .get();

    if (authorityQuery.docs.isNotEmpty) {
      final doc = authorityQuery.docs.first;
      _currentFirestoreId = doc.id;
      _currentUserType = 'authority';
      return;
    }

    // If no mapping found, use authUid as the ID
    _currentFirestoreId = _currentAuthUid;
    _currentUserType = null;
  }

  /// Get the current Firestore ID (returns authUid if no mapping exists)
  static String get firestoreId {
    if (!_isInitialized) {
      return"";
    }
    return _currentFirestoreId ?? _currentAuthUid ?? '';
  }

  /// Get the current Auth UID
  static String get authUid {
    if (!_isInitialized) {
      "";
    }
    return _currentAuthUid ?? '';
  }

  /// Get the current user type ('company', 'authority', or null)
  static String? get userType => _currentUserType;

  /// Check if the user is a company
  static bool get isCompany => _currentUserType == 'company';

  /// Check if the user is an authority
  static bool get isAuthority => _currentUserType == 'authority';

  /// Check if the user has a mapped Firestore ID (not using authUid as fallback)
  static bool get hasMappedId => _currentFirestoreId != null &&
      _currentFirestoreId != _currentAuthUid;

  /// Link a system-created Firestore ID to the current Auth UID
  static Future<void> linkToFirestoreId({
    required String firestoreId,
    required String userType, // 'company' or 'authority'
  }) async {
    if (_currentAuthUid == null) {
      return;
    }

    // Store mapping
    await FirebaseFirestore.instance
        .collection('auth_mappings')
        .doc(_currentAuthUid)
        .set({
      'firestoreId': firestoreId,
      'userType': userType,
      'authUid': _currentAuthUid,
      'linkedAt': FieldValue.serverTimestamp(),
    });

    // // Also update the user document with authUid reference
    // final collectionPath = userType == 'company'
    //     ? 'companies/companies'
    //     : 'authorities/authorities';
    //
    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(collectionPath.split('/').first)
    //     .collection(collectionPath.split('/').last)
    //     .doc(firestoreId)
    //     .update({
    //   'authUid': _currentAuthUid,
    //   'claimedAt': FieldValue.serverTimestamp(),
    //   'claimed': true,
    // });

    // Update local variables
    _currentFirestoreId = firestoreId;
    _currentUserType = userType;
  }

  /// Refresh the current user's ID (call after login/claim)
  static Future<void> refresh() async {
    _isInitialized = false;
    await initialize();
  }

  /// Clear the current session (call on logout)
  static void clear() {
    _currentFirestoreId = null;
    _currentAuthUid = null;
    _currentUserType = null;
    _isInitialized = false;
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;
  }
