import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../itc_logic/localDB/sharedPreference.dart';

class EmailAccountSetupPage extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onSkip;

  const EmailAccountSetupPage({
    Key? key,
    this.onSuccess,
    this.onSkip,
  }) : super(key: key);

  @override
  State<EmailAccountSetupPage> createState() => _EmailAccountSetupPageState();
}

class _EmailAccountSetupPageState extends State<EmailAccountSetupPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.compose',
    ],
  );

  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() => _errorMessage = 'No account selected');
        return;
      }

      final authHeaders = await account.authHeaders;
      final accessToken = authHeaders['Authorization']?.replaceFirst('Bearer ', '');

      if (accessToken == null) {
        setState(() => _errorMessage = 'Failed to get access token');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        setState(() => _errorMessage = 'No authenticated user found');
        return;
      }

      await UserPreferences.saveAccessToken(
        email: user.email!,
        accessToken: accessToken,
        expiresInSeconds: 3600,
      );

      debugPrint('✅ Access token saved for email: ${account.email}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected as ${account.email}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }

      Navigator.pop(context);

    } catch (e) {
      debugPrint('Error signing in: $e');
      setState(() => _errorMessage = 'Failed to sign in. Please try again.');
    } finally {
      setState(() => _isSigningIn = false);
    }
  }

  void _skipForNow() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface.withOpacity(0.7)),
          onPressed: _skipForNow,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Email Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.email_outlined,
                    size: 60,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Choose Email Account',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Select the Google account you\'ll use to send emails to trainees, companies, and other users.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Emails will be sent from your selected account. You can change this later in Settings.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Buttons
                if (_isSigningIn)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting...',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      // Continue with Google Button
                      _buildGoogleSignInButton(context),
                      const SizedBox(height: 16),

                      // Skip button
                      TextButton(
                        onPressed: _skipForNow,
                        child: Text(
                          'Skip for now',
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google logo
            Image.network(
              'https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_92x30dp.png',
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.g_mobiledata,
                size: 24,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simplified helper function to navigate to email setup
Future<bool> showEmailAccountSetup(BuildContext context) async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => EmailAccountSetupPage(
        onSuccess: () {
          debugPrint('Email account connected');
        },
        onSkip: () {
          debugPrint('User skipped email setup');
        },
      ),
    ),
  );
  return result ?? false;
}

// Simplified function to check and get access token
Future<String?> getEmailAccessToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      debugPrint('No authenticated user found');
      return null;
    }

    final token = await UserPreferences.getAccessToken(user.email!);

    if (token == null) {
      debugPrint('No access token found for user: ${user.email}');
      return null;
    }

    final isExpired = await UserPreferences.isTokenExpired(user.email!);
    if (isExpired) {
      debugPrint('Token expired for user: ${user.email}');
      return null;
    }

    return token;
  } catch (e) {
    debugPrint('Error getting email access token: $e');
    return null;
  }
}

// Simplified email sending function
Future<bool> sendEmailWithToken({
  required String to,
  required String subject,
  required String body,
  required BuildContext context,
}) async {
  final accessToken = await getEmailAccessToken();

  if (accessToken == null) {
    final shouldShowSetup = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Email Account Required'),
        content: const Text('You need to connect a Google account to send emails. Would you like to set it up now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set Up'),
          ),
        ],
      ),
    );

    if (shouldShowSetup == true) {
      await showEmailAccountSetup(context);
      final newToken = await getEmailAccessToken();
      if (newToken != null) {
        return await _sendEmailWithToken(
          to: to,
          subject: subject,
          body: body,
          accessToken: newToken,
        );
      }
    }
    return false;
  }

  return await _sendEmailWithToken(
    to: to,
    subject: subject,
    body: body,
    accessToken: accessToken,
  );
}

Future<bool> _sendEmailWithToken({
  required String to,
  required String subject,
  required String body,
  required String accessToken,
}) async {
  try {
    debugPrint('Sending email to: $to');
    debugPrint('Subject: $subject');
    debugPrint('Access token: ${accessToken.substring(0, 20)}...');

    // TODO: Implement actual email sending using the access token
    // Example using Gmail API:
    // final response = await http.post(
    //   Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send'),
    //   headers: {
    //     'Authorization': 'Bearer $accessToken',
    //     'Content-Type': 'application/json',
    //   },
    //   body: jsonEncode({'raw': base64Url.encode(utf8.encode(emailContent))}),
    // );

    return true;
  } catch (e) {
    debugPrint('Error sending email: $e');
    return false;
  }
}