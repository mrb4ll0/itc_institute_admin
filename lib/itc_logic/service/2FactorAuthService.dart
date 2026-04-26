import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';

import '../idservice/globalIdService.dart';

class TwoFactorAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFunctions _functions;
  bool _isTestMode = true;

  // Constructor to initialize with region
  TwoFactorAuthService() {
    // Explicitly set the region to match your functions
    _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  }

  // ========== SMS 2FA Methods ==========

  Future<bool> isTwoFactorEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final factors = await user.multiFactor.getEnrolledFactors();
    return factors.isNotEmpty;
  }

  Future<List<MultiFactorInfo>> getEnrolledFactors() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    await user.reload();
    return await user.multiFactor.getEnrolledFactors();
  }

  Future<MultiFactorSession> getMultiFactorSession() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    return await user.multiFactor.getSession();
  }

  Future<void> reauthenticateUser(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('User not found');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<String> sendEnrollmentCode({
    required String phoneNumber,
    required MultiFactorSession session,
    RecaptchaVerifier? verifier,
  }) async {
    final completer = Completer<String>();

    if (_isTestMode) {
      await _auth.setSettings(
        appVerificationDisabledForTesting: true,
        forceRecaptchaFlow: false,
      );
    }

    debugPrint("Sending verification code to: $phoneNumber");

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      multiFactorSession: session,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        debugPrint("Auto-verification completed");
        await _completeEnrollment(credential);
        if (!completer.isCompleted) completer.complete('auto');
      },
      verificationFailed: (error) {
        debugPrint("Verification failed: ${error.code} - ${error.message}");
        final userMessage = _getFriendlyErrorMessage(error);
        if (!completer.isCompleted) completer.completeError(userMessage);
      },
      codeSent: (verificationId, forceResendingToken) {
        debugPrint("Code sent successfully");
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  String _getFriendlyErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'requires-recent-login':
        return 'For security reasons, please re-login to continue.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Please enter a valid phone number with country code (e.g., +1234567890).';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'captcha-check-failed':
        return 'Security verification failed. Please try again.';
      default:
        return error.message ?? 'An error occurred. Please try again.';
    }
  }

  Future<String> sendSignInCode({
    required PhoneMultiFactorInfo factor,
    required MultiFactorSession session,
  }) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      multiFactorSession: session,
      multiFactorInfo: factor,
      verificationCompleted: (credential) async {
        final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
        completer.complete('auto');
      },
      verificationFailed: (error) {
        completer.completeError(error);
      },
      codeSent: (verificationId, forceResendingToken) {
        completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  Future<void> completeEnrollment({
    required String verificationId,
    required String smsCode,
    required String displayName,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await user.multiFactor.enroll(assertion, displayName: displayName);
  }

  Future<void> _completeEnrollment(PhoneAuthCredential credential) async {
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    final user = _auth.currentUser;
    if (user != null) {
      await user.multiFactor.enroll(assertion, displayName: 'Verified Device');
    }
  }

  Future<UserCredential> completeSignInWithTwoFactor({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    return await resolver.resolveSignIn(assertion);
  }

  Future<void> unenrollFactor(String factorUid) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await user.multiFactor.unenroll(factorUid: factorUid);
  }

  Future<void> unenrollFactorByInfo(MultiFactorInfo factorInfo) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await user.multiFactor.unenroll(multiFactorInfo: factorInfo);
  }

  // ========== Password-based 2FA Methods (Cloud Functions) ==========


  /// Set a password-based 2FA fallback and return backup codes
  Future<List<String>> setTwoFactorPassword(String password) async {
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    try {
      final callable = _functions.httpsCallable('setTwoFactorPassword');
      final result = await callable.call({
        'password': password,
        'generateBackupCodes': true,
      });
      final data = result.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to set 2FA password');
      }

      // Return backup codes if available
      if (data['backupCodes'] != null && data['backupCodes'] is List) {
        return List<String>.from(data['backupCodes']);
      }

      return [];

    } on FirebaseFunctionsException catch (e) {
      debugPrint('FirebaseFunctionsException: ${e.code} - ${e.message}');
      throw Exception('Failed to set 2FA password: ${e.message}');
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      debugPrint('Error setting 2FA password: $e');
      throw Exception('Failed to set 2FA password: $e');
    }
  }
  /// Verify a password-based 2FA fallback
  Future<bool> verifyTwoFactorPassword(String password) async {
    try {
      final callable = _functions.httpsCallable('verifyTwoFactorPassword');
      final result = await callable.call({'password': password});
      final data = result.data as Map<String, dynamic>;
      return data['isValid'] ?? false;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        return false;
      }
      debugPrint('Error verifying 2FA password: $e');
      throw Exception('Failed to verify 2FA password: $e');
    }
  }

  /// Check if user has a password-based 2FA set
  Future<bool> hasTwoFactorPassword() async {
    final userId = GlobalIdService.firestoreId;
    if (userId == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('twoFactorPasswords')
        .doc(userId)
        .get();

    return doc.exists;
  }

  /// Remove password-based 2FA
  Future<void> removeTwoFactorPassword() async {
    try {
      final callable = _functions.httpsCallable('removeTwoFactorPassword');
      await callable.call({});
      debugPrint('2FA password removed successfully');
    } catch (e) {
      debugPrint('Error removing 2FA password: $e');
      throw Exception('Failed to remove 2FA password: $e');
    }
  }

  // Add these methods to your TwoFactorAuthService class

  /// Generate backup codes for 2FA
  Future<List<String>> generateBackupCodes() async {
    try {
      final callable = _functions.httpsCallable('generateBackupCodes');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return List<String>.from(data['codes']);
    } catch (e,s) {
      debugPrintStack(stackTrace: s);
      throw Exception('Failed to generate backup codes: $e');
    }
  }

  /// Verify a backup code
  Future<bool> verifyBackupCode(String backupCode) async {
    try {
      final callable = _functions.httpsCallable('verifyBackupCode');
      final result = await callable.call({'backupCode': backupCode});
      final data = result.data as Map<String, dynamic>;
      return data['isValid'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get remaining backup codes count
  Future<int> getRemainingBackupCodesCount() async {
    try {
      final callable = _functions.httpsCallable('getRemainingBackupCodesCount');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return data['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Regenerate backup codes
  Future<List<String>> regenerateBackupCodes() async {
    try {
      final callable = _functions.httpsCallable('regenerateBackupCodes');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return List<String>.from(data['codes']);
    } catch (e) {
      throw Exception('Failed to regenerate backup codes: $e');
    }
  }
}