import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:itc_institute_admin/extensions/extensions.dart';
import 'package:itc_institute_admin/itc_logic/service/securitySettingsService.dart';
import 'package:itc_institute_admin/view/security/securitySettingsPage.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:itc_institute_admin/auth/signup.dart';
import 'package:itc_institute_admin/backgroundTask/backgroundTask.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/localDB/sharedPreference.dart';
import 'package:itc_institute_admin/itc_logic/notification/notificationPanel/notificationPanelService.dart';
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';
import 'package:itc_institute_admin/itc_logic/service/privacySettingsService.dart';
import 'package:itc_institute_admin/migrationService/migrationManager.dart';
import 'package:itc_institute_admin/migrationService/migrationService.dart';
import 'package:itc_institute_admin/migrationService/ui/migrationSettingsPage.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/model/localNotification.dart';
import 'package:itc_institute_admin/model/notificationModel.dart';
import 'package:itc_institute_admin/model/privacySettingModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backgroundTask/backgroundTaskRegistry.dart';
import '../itc_logic/admin_task.dart';
import '../itc_logic/firebase/general_cloud.dart';
import '../itc_logic/idservice/globalIdService.dart';
import '../itc_logic/service/ConnectedDeviceService.dart';
import '../migrationService/migrationSettingsStrorage.dart';
import '../model/authority.dart';
import '../model/company.dart';
import '../model/securitySettingsModel.dart';
import '../view/home/companyDashboardController.dart';
import '../view/twoFactorAuthentication/TwoFactorVerificationScreen.dart';
import 'authService/emailChoosingPage.dart';

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
  bool _isCheckingAuth = true;
  final NotificationService notificationService = NotificationService();
  int failedCount = 0;
  final adminCloud = AdminCloud(GlobalIdService.firestoreId ?? "");

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

  Future<void> _checkExistingAuth() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isCheckingAuth = false);
        return;
      }

      setState(() => _isLoading = true);
      PrivacySettings privacySettings =
      await PrivacySettingsService.getUserPrivacySettings(GlobalIdService.firestoreId);

      if (privacySettings.twoFactorAuth) {
        GeneralMethods.navigateTo(
          context,
          TwoFactorVerificationScreen(
            privacySettings: privacySettings,
            email: currentUser.email ?? "",
            onSuccess: (credential, user) async {
              await _handleSuccessfulLogin(null, privacySettings);
            },
          ),
        );
      } else {
        await _handleSuccessfulLogin(null, privacySettings);
      }
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      setState(() {
        _isCheckingAuth = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    await adminCloud.syncUserAccountLock(_emailController.text);
    adminCloud.syncAllAccountLocks();

    final isLocked = await UserPreferences.isAccountLocked(_emailController.text);
    final lockDetails = await UserPreferences.getLockExpiryTime(_emailController.text);

    if (isLocked) {
      GeneralMethods.showTemporaryLockDialog(
        context: context,
        reason: "Failed Attempt max reached",
        remainingSeconds: GeneralMethods.getRemainingSecondsFromDateTime(lockDetails),
      );
      return;
    }

    SecuritySettings securitySettings =
    await SecuritySettingsService.getUserSecuritySettings(
      GlobalIdService.firestoreId ?? "",
    );

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user == null) {
        _showError("User is null");
        setState(() => _isLoading = false);
        return;
      }

      PrivacySettings privacy =
      await PrivacySettingsService.getUserPrivacySettings(
        userCredential.user!.uid,
      );

      if (privacy.twoFactorAuth) {
        setState(() => _isLoading = false);
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TwoFactorVerificationScreen(
                forcedType: TwoFactorType.password,
                privacySettings: privacy,
                resolver: null,
                email: _emailController.text.trim(),
                onSuccess: (userCredential, user) async {
                  await _handleSuccessfulLogin(userCredential, privacy);
                },
              ),
            ),
          );
        }
      } else {
        await _handleSuccessfulLogin(userCredential, privacy);
      }
    } on FirebaseAuthMultiFactorException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TwoFactorVerificationScreen(
              forcedType: TwoFactorType.sms,
              resolver: e.resolver,
              email: _emailController.text.trim(),
              onSuccess: (userCredential, user) async {
                await _handleSuccessfulLogin(userCredential, null);
              },
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getAuthErrorMessage(e.code));
      if (e.code == 'invalid-credential') {
        failedCount++;
        if (securitySettings != null &&
            securitySettings.failedLoginAlerts &&
            failedCount >= securitySettings.maxFailedAttempts) {
          final deviceName = await _getDeviceName();
          final ipAddress = await _getIpAddress();
          final location = await _getLocation();
          final fcmToken = await FirebaseMessaging.instance.getToken();
          notifyFailedAttempt(
            _emailController.text,
            ipAddress,
            deviceName,
            fcmToken,
            location,
          );
          if (securitySettings.lockAfterFailedAttempts) {
            final user = await adminCloud.getCompanyOrAuthorityByEmail(
              _emailController.text,
            );
            if (user is Company) {
              adminCloud.lockAccountWithDuration(
                userId: user.id,
                email: _emailController.text,
                duration: securitySettings.lockDurationMinutes.minutes,
                userType: user.role,
              );
            } else if (user is Authority) {
              adminCloud.lockAccountWithDuration(
                userId: user.id,
                email: _emailController.text,
                duration: securitySettings.lockDurationMinutes.minutes,
                userType: 'authority',
              );
            }
          }
        }
      }
      setState(() => _isLoading = false);
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      _showError("An unexpected error occurred. Please try again.");
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );

        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          String location = '';
          if (place.locality != null) location += place.locality!;
          if (place.country != null) {
            if (location.isNotEmpty) location += ', ';
            location += place.country!;
          }
          return location.isEmpty ? 'Unknown Location' : location;
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
    return 'Unknown Location';
  }

  Future<void> _handleSuccessfulLogin(
      UserCredential? userCredential,
      PrivacySettings? privacySettings,
      ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    SecuritySettings securitySettings =
    await SecuritySettingsService.getUserSecuritySettings(
      GlobalIdService.firestoreId,
    );
    await GlobalIdService.initialize();
    Company? company;
    company = await ITCFirebaseLogic(
      GlobalIdService.firestoreId,
    ).getCompany(GlobalIdService.firestoreId);

    if (company == null) {
      Authority? authority = await ITCFirebaseLogic(
        GlobalIdService.firestoreId,
      ).getAuthority(GlobalIdService.firestoreId);
      if (authority != null) {
        company = AuthorityCompanyMapper.createCompanyFromAuthority(
          authority: authority,
        );
      }
    }

    if (company == null) {
      _showError("Company or Authority profile not found. Please contact support.");
      setState(() => _isLoading = false);
      return;
    }

    await notificationService.saveTokenToFirestore();
    if (securitySettings != null && securitySettings.loginAlerts) {
      final deviceName = await _getDeviceName();
      final ipAddress = await _getIpAddress();
      final location = await _getLocation();
      notifyUser(deviceName, ipAddress, null);
    }
    await ConnectedDeviceService().saveCurrentDevice();
    final settings = await MigrationSettingsStorage.loadSettings();
    MigrationTrigger trigger = settings["trigger"];
    MigrationManager().doMigration(trigger);

    if (mounted) {
      GeneralMethods.replaceNavigationTo(
        context,
        CompanyDashboardController(tweetCompany: company),
      );
    }
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return "${androidInfo.model} (Android ${androidInfo.version.release})";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return "${iosInfo.model} (iOS ${iosInfo.systemVersion})";
    } else {
      return "Unknown Device";
    }
  }

  Future<String> _getIpAddress() async {
    try {
      final info = NetworkInfo();
      final localIp = await info.getWifiIP();
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }
      return localIp ?? "Unknown IP";
    } catch (e) {
      return "Unknown IP";
    }
  }

  notifyUser(String deviceName, String ipAddress, String? fcmToken) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    fcmToken ??= await FirebaseMessaging.instance.getToken();
    final timestamp = DateTime.now();
    final formattedTime = DateFormat('MMM dd, yyyy hh:mm a').format(timestamp);

    NotificationModel notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "⚠️ New Login Detected",
      body:
      "Your account was accessed from a new device.\n\n"
          "📱 Device: $deviceName\n"
          "🌐 IP Address: $ipAddress\n"
          "🕐 Time: $formattedTime\n\n"
          "If this wasn't you, please secure your account immediately.",
      timestamp: timestamp,
      read: false,
      targetAudience: currentUser.email ?? '',
      targetStudentId: GlobalIdService.firestoreId,
      fcmToken: fcmToken ?? "",
      type: NotificationType.systemAlert.name,
    );

    NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(
      notification,
    );
  }

  Future<void> notifyFailedAttempt(
      String email,
      String ipAddress,
      String? deviceName,
      String? fcmToken,
      String location,
      ) async {
    final timestamp = DateTime.now();
    final formattedTime = DateFormat('MMM dd, yyyy hh:mm a').format(timestamp);

    NotificationModel notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "⚠️ Failed Login Attempt Detected",
      body:
      "A failed login attempt was detected on your account.\n\n"
          "📧 Email: $email\n"
          "📱 Device: $deviceName\n"
          "🌐 IP Address: $ipAddress\n"
          "📍 Location: $location\n"
          "🕐 Time: $formattedTime\n\n"
          "If this wasn't you, please secure your account immediately.",
      timestamp: timestamp,
      read: false,
      targetAudience: email,
      targetStudentId: '',
      fcmToken: fcmToken ?? "",
      type: NotificationType.systemAlert.name,
    );

    NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(
      notification,
    );
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
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
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

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return _buildLoadingScreen();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 600 ? 80 : 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section
                      _buildHeader(theme, isDarkMode),

                      const SizedBox(height: 48),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'admin@company.com',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter your email';
                          }
                          if (!value!.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: theme.colorScheme.primary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        validator: (value) =>
                        (value?.length ?? 0) < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sign Up Button
                      OutlinedButton(
                        onPressed: () {
                          GeneralMethods.navigateTo(context, CompanySignupScreen());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Create New Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Text Section - Left aligned
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Welcome back" - very small
            Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            // IT Connect - Big text
            Text(
              'IT Connect',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF667EEA),
                letterSpacing: 1,
              ),
            ),
            // Subtitle - very small
            Text(
              'Your Industrial Training Gap Bridge',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                height: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              "Checking authentication...",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Please wait",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final theme = Theme.of(context);
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
                if (_emailController.text.isEmpty) {
                  _showError("Please enter your email.");
                  return;
                }

                try {
                  final email = _emailController.text;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Sending password reset email..."),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: email,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Password reset email sent. Check your inbox.",
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
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
              child: Text(
                "Send Reset Link",
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}

//// After user claims their account
// Future<void> claimAccount(String systemCreatedId, String userType) async {
//   try {
//     await GlobalIdService.linkToFirestoreId(
//       firestoreId: systemCreatedId,
//       userType: userType,
//     );
//
//     // Refresh the global ID
//     await GlobalIdService.refresh();
//
//     // Proceed to dashboard
//     if (GlobalIdService.isCompany) {
//       navigateToCompanyDashboard();
//     } else {
//       navigateToAuthorityDashboard();
//     }
//   } catch (e) {
//     // Handle error
//   }
// }