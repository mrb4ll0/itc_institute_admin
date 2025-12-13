import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:itc_institute_admin/auth/signup.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';

import '../itc_logic/firebase/general_cloud.dart';
import '../model/company.dart';
import '../view/home/companyDashboardController.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isCheckingAuth = true; // Added for initial auth check
  int _currentStep = 0; // 0: Email, 1: Password, 2: Login
  final NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Check if user is already logged in and has a company
  Future<void> _checkExistingAuth() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      // If no user is logged in, show login screen
      if (currentUser == null) {
        setState(() {
          _isCheckingAuth = false;
        });
        return;
      }

      // User is logged in, check if they have a company
      setState(() {
        _isLoading = true;
      });

      Company? company = await ITCFirebaseLogic().getCompany(currentUser.uid);

      if (company != null) {
        // User has a company, navigate to dashboard
        if (mounted) {
          GeneralMethods.replaceNavigationTo(
            context,
            CompanyDashboardController(),
          );
        }
      } else {
        // User logged in but no company found - show login screen
        setState(() {
          _isCheckingAuth = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error checking auth, show login screen
      debugPrint("Error checking auth: $e");
      setState(() {
        _isCheckingAuth = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _currentStep = 2; // Move to loading step
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // Check if user has a company
      Company? company = await ITCFirebaseLogic().getCompany(
        userCredential.user!.uid,
      );

      if (company == null) {
        _showError("Company profile not found. Please contact support.");
        setState(() {
          _isLoading = false;
          _currentStep = 1; // Go back to password step on error
        });
        return;
      }
      await notificationService.saveTokenToFirestore();
      // Successfully logged in with company, navigate to dashboard
      if (mounted) {
        GeneralMethods.replaceNavigationTo(
          context,
          CompanyDashboardController(),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getAuthErrorMessage(e.code));
      setState(() {
        _isLoading = false;
        _currentStep = 1; // Go back to password step on error
      });
    } catch (e) {
      _showError("An unexpected error occurred. Please try again.");
      setState(() {
        _isLoading = false;
        _currentStep = 1; // Go back to password step on error
      });
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && _emailController.text.trim().isNotEmpty) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      _login();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking auth
    if (_isCheckingAuth) {
      return _buildLoadingScreen();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width > 600 ? 80 : 24,
              vertical: 40,
            ),
            height: size.height,
            child: Column(
              children: [
                // Logo and Welcome
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Welcome Admin",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sign in to your dashboard",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Progress Stepper
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepCircle(0, "Email", _currentStep >= 0),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 1
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                      ),
                      _buildStepCircle(1, "Password", _currentStep >= 1),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 2
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                      ),
                      _buildStepCircle(2, "Login", _currentStep == 2),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Form Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentStep == 0
                          ? _buildEmailStep(isDarkMode)
                          : _currentStep == 1
                          ? _buildPasswordStep(isDarkMode)
                          : _buildLoadingStep(),
                    ),
                  ),
                ),

                // Navigation Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: _previousStep,
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Back",
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(width: 100),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentStep == 0
                                      ? "Continue"
                                      : _currentStep == 1
                                      ? "Sign In"
                                      : "Processing",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_currentStep < 2 && !_isLoading) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Forgot Password
                TextButton(
                  onPressed: () {
                    _showForgotPasswordDialog();
                  },
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        GeneralMethods.navigateTo(
                          context,
                          CompanySignupScreen(),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              "Checking authentication...",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              "Please wait while we check your login status",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(int stepNumber, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.blue : Colors.grey[300],
            border: Border.all(
              color: isActive ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive
                ? Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    (stepNumber + 1).toString(),
                    style: TextStyle(
                      color: stepNumber <= _currentStep
                          ? Colors.white
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey[500],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Enter your email",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.blueGrey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We'll use this to identify your account",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _emailController,
          autofocus: true,
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: 'Company Email',
            hintText: 'admin@company.com',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter your email';
            }
            if (!value!.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email';
            }
            return null;
          },
          onFieldSubmitted: (_) => _nextStep(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Use your registered company email address",
                  style: TextStyle(color: Colors.blue[700], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Enter your password",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.blueGrey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the password for ${_emailController.text}",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _passwordController,
          autofocus: true,
          enabled: !_isLoading,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[500],
              ),
              onPressed: _isLoading
                  ? null
                  : () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
          ),
          validator: (value) => (value?.length ?? 0) < 6
              ? 'Password must be at least 6 characters'
              : null,
          onFieldSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.security_outlined, color: Colors.amber[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "For security, your password is encrypted and never stored in plain text",
                  style: TextStyle(color: Colors.amber[700], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 3,
                  ),
                ),
              ),
              Center(
                child: Icon(Icons.lock_outlined, size: 30, color: Colors.blue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Signing you in...",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Verifying your credentials and\nsetting up your dashboard",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: const Text(
            "Enter your email address and we'll send you a password reset link.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Implement password reset
                if (_emailController.text.isEmpty) {
                  _showError("Please enter your email.");
                  return;
                }

                try {
                  // Get the email first
                  final email = _emailController.text;
                  debugPrint("email is $email");

                  // Close the dialog first
                  Navigator.pop(context);

                  // Show a loading indicator
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text("Sending password reset email..."),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );

                  // Show success message
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Password reset email sent. Check your inbox.",
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e, s) {
                  debugPrint("Error sending password reset email: $e");
                  debugPrintStack(stackTrace: s);

                  // Show error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Failed to send reset email. Please try again.",
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              child: const Text("Send Reset Link"),
            ),
          ],
        );
      },
    );
  }
}
