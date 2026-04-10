import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geocoding/geocoding.dart';
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
import 'package:http/http.dart' as http;
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
import '../itc_logic/firebase/general_cloud.dart';
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
      // final firebaseToken = await currentUser?.getIdToken();
      // final response = await http.post(
      //   Uri.parse('https://taswreiddfnunhczxmqn.supabase.co/functions/v1/firebase-to-supabase'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'firebaseToken': firebaseToken}),
      // );
      //
      // debugPrint('Status code: ${response.statusCode}');
      // debugPrint('Body: ${response.body}');
      // final supabaseJwt = jsonDecode(response.body)['supabaseJwt'];
      // final supabase = Supabase.instance.client;
      // await supabase.auth.setSession(
      //   supabaseJwt,
      // );
      //
      // final session = supabase.auth.currentSession;
      // if (session == null) {
      //   Fluttertoast.showToast(msg: "Internal Error you can't upload an image");
      // } else {
      //   Fluttertoast.showToast(msg: "Image upload activated");
      // }
      // User is logged in, check if they have a company
      setState(() {
        _isLoading = true;
      });
      PrivacySettings privacySettings =
          await PrivacySettingsService.getUserPrivacySettings(currentUser.uid);

      if (privacySettings.twoFactorAuth) {
        GeneralMethods.navigateTo(
          context,
          TwoFactorVerificationScreen(
            privacySettings: privacySettings,
            email: currentUser.email ?? "",
            onSuccess: (credential,user) async {
              Company? company;
              company = await ITCFirebaseLogic(
                FirebaseAuth.instance.currentUser!.uid,
              ).getCompany(currentUser.uid);
              if (company == null) {
                Authority? authority = await ITCFirebaseLogic(
                  FirebaseAuth.instance.currentUser!.uid,
                ).getAuthority(currentUser.uid);
                if (authority != null) {
                  company = AuthorityCompanyMapper.createCompanyFromAuthority(
                    authority: authority,
                  );
                }
              }

              if (company != null) {
                final settings = await MigrationSettingsStorage.loadSettings();

                MigrationTrigger trigger = settings["trigger"];

                debugPrint("trigger is ${trigger.displayName}");

                MigrationManager().doMigration(trigger);

                debugPrint("after the backgroundTaskManger line");
                // User has a company, navigate to dashboard
                // String? accessToken = await UserPreferences.getAccessToken(
                //   currentUser.email ?? "",
                // );
                // if (accessToken == null) {
                //   await showEmailAccountSetup(context);
                // }

                if (mounted) {
                  GeneralMethods.replaceNavigationTo(
                    context,
                    CompanyDashboardController(tweetCompany: company),
                  );
                }
              } else {
                // User logged in but no company found - show login screen
                setState(() {
                  _isCheckingAuth = false;
                  _isLoading = false;
                });
              }
            },
          ),
        );
      } else {
        Company? company;
        company = await ITCFirebaseLogic(
          FirebaseAuth.instance.currentUser!.uid,
        ).getCompany(currentUser.uid);
        if (company == null) {
          Authority? authority = await ITCFirebaseLogic(
            FirebaseAuth.instance.currentUser!.uid,
          ).getAuthority(currentUser.uid);
          if (authority != null) {
            company = AuthorityCompanyMapper.createCompanyFromAuthority(
              authority: authority,
            );
          }
        }

        if (company != null) {
          final settings = await MigrationSettingsStorage.loadSettings();

          MigrationTrigger trigger = settings["trigger"];

          debugPrint("trigger is ${trigger.displayName}");

          MigrationManager().doMigration(trigger);

          debugPrint("after the backgroundTaskManger line");
          // User has a company, navigate to dashboard
          // String? accessToken = await UserPreferences.getAccessToken(
          //   currentUser.email ?? "",
          // );
          // if (accessToken == null) {
          //   await showEmailAccountSetup(context);
          // }

          if (mounted) {
            GeneralMethods.replaceNavigationTo(
              context,
              CompanyDashboardController(tweetCompany: company),
            );
          }
        } else {
          // User logged in but no company found - show login screen
          setState(() {
            _isCheckingAuth = false;
            _isLoading = false;
          });
        }
      }
    } catch (e, s) {
      // Error checking auth, show login screen
      debugPrintStack(stackTrace: s);
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
    SecuritySettings securitySettings =  await SecuritySettingsService.getUserSecuritySettings(FirebaseAuth.instance.currentUser?.uid??"");

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

      if (userCredential.user == null) {
        _showError("User is null");
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });
        return;
      }

      // Check if user has 2FA enabled in their privacy settings
      PrivacySettings privacy =
          await PrivacySettingsService.getUserPrivacySettings(
            userCredential.user!.uid,
          );

      if (privacy.twoFactorAuth) {
        // User has 2FA enabled - always go to 2FA verification screen
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TwoFactorVerificationScreen(
                forcedType: TwoFactorType.password,
                privacySettings: privacy,
                resolver: null, // No resolver for password-based 2FA
                email: _emailController.text.trim(),
                onSuccess: (userCredential,user) async {
                  await _handleSuccessfulLogin(userCredential,privacy);
                },
              ),
            ),
          );
        }
      } else {
        // No 2FA required
        await _handleSuccessfulLogin(userCredential,privacy);
      }
    } on FirebaseAuthMultiFactorException catch (e) {
      // SMS 2FA is required (Firebase-enforced)
      debugPrint('SMS 2FA required for user');
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TwoFactorVerificationScreen(
              forcedType: TwoFactorType.sms,
              resolver: e.resolver,
              email: _emailController.text.trim(),
              onSuccess: (userCredential,user) async {
                if(userCredential == null)
                {
                  Fluttertoast.showToast(msg: "Error: User Credential is null");
                  return;
                }
                await _handleSuccessfulLogin(userCredential,null);
              },
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getAuthErrorMessage(e.code));
       if(e.code == 'invalid-credential')
         {

           if(securitySettings != null && securitySettings.failedLoginAlerts)
             {
               final deviceName = await _getDeviceName();
               final ipAddress = await _getIpAddress();
               final location = await _getLocation();
               final fcmToken = await FirebaseMessaging.instance.getToken();
               notifyFailedAttempt(_emailController.text,ipAddress, deviceName, fcmToken,location);
             }
         }
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    } catch (e, s) {
      debugPrintStack(stackTrace: s);
      debugPrint("error is $e");
      _showError("An unexpected error occurred. Please try again.");
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    }
  }
  // Get location
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


  // Extract successful login logic to a separate method
  Future<void> _handleSuccessfulLogin(UserCredential? userCredential,PrivacySettings? privacySettings) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint("currentUser is $currentUser");
    SecuritySettings securitySettings =  await SecuritySettingsService.getUserSecuritySettings(currentUser?.uid??"");

    // Check if user has a company
    Company? company;
    company = await ITCFirebaseLogic(
      FirebaseAuth.instance.currentUser!.uid,
    ).getCompany(currentUser!.uid);

    if (company == null) {
      Authority? authority = await ITCFirebaseLogic(
        FirebaseAuth.instance.currentUser!.uid,
      ).getAuthority(currentUser.uid);
      if (authority != null) {
        company = AuthorityCompanyMapper.createCompanyFromAuthority(
          authority: authority,
        );
      }
    }

    if (company == null) {
      _showError(
        "Company or Authority profile not found. Please contact support.",
      );
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
      return;
    }

    //debugPrint('company is $company and ${company.originalAuthority == null}');
    await notificationService.saveTokenToFirestore();
    if (securitySettings != null && securitySettings.loginAlerts) {
      // Get device information
      final deviceName = await _getDeviceName();
      final ipAddress = await _getIpAddress();
      final location = await _getLocation();

      notifyUser(deviceName, ipAddress,null);
    }
    await ConnectedDeviceService().saveCurrentDevice();
    final settings = await MigrationSettingsStorage.loadSettings();
    MigrationTrigger trigger = settings["trigger"];
    debugPrint("trigger is ${trigger.displayName}");
    MigrationManager().doMigration(trigger);

    // String? accessToken = await UserPreferences.getAccessToken(
    //   currentUser?.email ?? "",
    // );
    // if (accessToken == null) {
    //   await showEmailAccountSetup(context);
    // }

    debugPrint("after the backgroundTaskManger line");

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
      // Get local IP
      final info = NetworkInfo();
      final localIp = await info.getWifiIP();

      // Get public IP
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }

      return localIp ?? "Unknown IP";
    } catch (e) {
      debugPrint('Error getting IP: $e');
      return "Unknown IP";
    }
  }

   notifyUser(String deviceName,String ipAddress,String? fcmToken)async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    fcmToken ??= await FirebaseMessaging.instance.getToken();

    final timestamp = DateTime.now();
    final formattedTime = DateFormat('MMM dd, yyyy hh:mm a').format(timestamp);

    NotificationModel notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "⚠️ New Login Detected",
      body: "Your account was accessed from a new device.\n\n"
          "📱 Device: $deviceName\n"
          "🌐 IP Address: $ipAddress\n"
          "🕐 Time: $formattedTime\n\n"
          "If this wasn't you, please secure your account immediately.",
      timestamp: timestamp,
      read: false,
      targetAudience: currentUser.email ?? '',
      targetStudentId: currentUser.uid,
      fcmToken:fcmToken ??"", // Will be handled by the service
      type: NotificationType.systemAlert.name,
    );

    NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(notification);
  }

  Future<void> notifyFailedAttempt(String email, String ipAddress, String? deviceName,String? fcmToken,String location) async {
    final timestamp = DateTime.now();
    final formattedTime = DateFormat('MMM dd, yyyy hh:mm a').format(timestamp);


    // Get location from IP (optional)
    final deviceName = await _getDeviceName();
    final ipAddress = await _getIpAddress();

    NotificationModel notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "⚠️ Failed Login Attempt Detected",
      body: "A failed login attempt was detected on your account.\n\n"
          "📧 Email: $email\n"
          "📱 Device: $deviceName\n"
          "🌐 IP Address: $ipAddress\n"
          "📍 Location: $location\n"
          "🕐 Time: $formattedTime\n\n"
          "If this wasn't you, please secure your account immediately by changing your password.",
      timestamp: timestamp,
      read: false,
      targetAudience: email,
      targetStudentId: '', // No user ID since login failed
      fcmToken: fcmToken??"", // Will be handled by the service to find user's tokens
      type: NotificationType.systemAlert.name,

    );

    // Send notification to the user's email and devices
    NotificationPanelService.sendNotificationToAllEnabledChannelsWithSummary(notification);
  }

  String _getAuthErrorMessage(String code) {
    debugPrint("code is $code");

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
        return 'Invalid credentials. Please ensure you entered the right email and password.';
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
    final padding = MediaQuery.of(context).padding;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 600 ? 80 : 24,
                vertical: 20, // Reduced from 40
              ),
              // Remove fixed height constraint
              constraints: BoxConstraints(
                minHeight: size.height - padding.top - padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // ← Changed to min
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and Welcome
                  _buildHeader(theme, isDarkMode),

                  const SizedBox(height: 40),

                  // Progress Stepper
                  _buildProgressStepper(),

                  const SizedBox(height: 40),

                  // Form Content - Removed Expanded
                  Form(
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

                  const SizedBox(height: 20),

                  // Navigation Buttons
                  _buildNavigationButtons(theme),

                  const SizedBox(height: 20),

                  // Forgot Password
                  _buildForgotPasswordButton(theme),

                  // Sign Up
                  _buildSignUpRow(theme),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Break down into smaller widgets for better organization
  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Column(
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
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepCircle(0, "Email", _currentStep >= 0),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 1 ? Colors.blue : Colors.grey[300],
            ),
          ),
          _buildStepCircle(1, "Password", _currentStep >= 1),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 2 ? Colors.blue : Colors.grey[300],
            ),
          ),
          _buildStepCircle(2, "Login", _currentStep == 2),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Row(
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_currentStep < 2 && !_isLoading) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordButton(ThemeData theme) {
    return TextButton(
      onPressed: _showForgotPasswordDialog,
      child: Text(
        "Forgot Password?",
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSignUpRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
        TextButton(
          onPressed: () {
            GeneralMethods.navigateTo(context, CompanySignupScreen());
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
