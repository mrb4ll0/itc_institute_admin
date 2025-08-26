import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:itc_institute_admin/view/login_view.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const Color bgDark = Color(0xFF122118);
  static const Color cardGreen = Color(0xFF264532);
  static const Color barGreen = Color(0xFF1B3124);
  static const Color textMuted = Color(0xFF96C5A9);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.splineSansTextTheme(
      Theme.of(context).textTheme,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ITC Institute Admin',
       theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        surface: bgDark,
        background: bgDark,
        primary: Colors.white,
        secondary: Colors.white,
      ),
      textTheme: baseTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
    ),
      home: LoginScreen()
    );
  }
}

