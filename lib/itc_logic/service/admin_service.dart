import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Logs in an admin with email and password.
  /// Returns the Firebase User object if successful.
  Future<User?> loginAdmin({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User user = userCredential.user!;
      return user;
    } on FirebaseAuthException catch (e) {
      // Handle specific FirebaseAuth errors here
      throw Exception("FirebaseAuthException: ${e.message}");
    } catch (e) {
      throw Exception("Unknown error: $e");
    }
  }
}
