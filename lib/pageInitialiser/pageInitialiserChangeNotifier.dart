import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_view.dart';
import '../itc_logic/firebase/provider/theme_provider.dart';
import '../itc_logic/notification/notitification_service.dart';

class InitializerPage extends StatefulWidget {
  const InitializerPage({super.key});

  @override
  State<InitializerPage> createState() => _InitializerPageState();
}

class _InitializerPageState extends State<InitializerPage> {
  Timer? _heartbeatTimer;


  void _finishInitialization() {
    _heartbeatTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 24.0 : 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo/icon container
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: isSmallScreen ? 100 : 120,
                    height: isSmallScreen ? 100 : 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      size: isSmallScreen ? 50 : 60,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Welcome text with elegant animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        "Welcome to",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "ITC Facilities",
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: isSmallScreen ? 32 : 40,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Custom animated loading indicator
                SizedBox(
                  width: isSmallScreen ? 60 : 70,
                  height: isSmallScreen ? 60 : 70,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 2000),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 2 * 3.14159,
                        child: child,
                      );
                    },
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                      strokeWidth: 4,
                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Subtle loading text
                Text(
                  "Loading amazing content",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.4),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // inside initializer_page.dart

  @override
  void initState() {
    super.initState();
    debugPrint("reached initialized init");
    // Start the heartbeat to keep the Vulkan/Impeller surface alive
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (mounted) setState(() {});
    });

    _startServices();
  }

  Future<void> _startServices() async {
    try {
      // Perform the heavy lifting HERE instead of main.dart
      await Firebase.initializeApp();
      await Supabase.initialize(
        url: 'https://taswreiddfnunhczxmqn.supabase.co',
        anonKey: 'your_key',
      );
      await NotificationService().init();

      FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);


      // Once done, go to login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print("Error during wake up: $e");
      // Handle error or retry
    }
  }

}
