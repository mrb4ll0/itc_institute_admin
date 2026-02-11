import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:itc_institute_admin/auth/tweet_provider.dart';
import 'package:itc_institute_admin/itc_logic/firebase/provider/theme_provider.dart';
import 'package:itc_institute_admin/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_view.dart';
import 'itc_logic/notification/notitification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://taswreiddfnunhczxmqn.supabase.co',//https://taswreiddfnunhczxmqn.supabase.co
    anonKey: 'sb_publishable_jM2JXPz4CCJlCTbhh4whng_zop872__',
  );


  await NotificationService().init();
  FirebaseMessaging.onBackgroundMessage(NotificationService.backgroundHandler);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TweetProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(), // Your light theme
          darkTheme: ThemeData.dark(), // Your dark theme
          themeMode: themeProvider.themeMode, // Use provider's theme
          home: const LoginScreen(),
        );
      },
    );
  }
}
