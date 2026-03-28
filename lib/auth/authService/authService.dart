import 'package:google_sign_in/google_sign_in.dart';

Future<String?> getGoogleAccessToken() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://mail.google.com/'], // 🔥 important
  );

  // Try silent sign-in (no popup)
  GoogleSignInAccount? user = googleSignIn.currentUser;

  user ??= await googleSignIn.signInSilently();

  if (user == null) {
    // fallback (will show UI)
    user = await googleSignIn.signIn();
  }

  final auth = await user!.authentication;

  return auth.accessToken;
}