import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Professional Color Palette
  static const Color _primaryColor = Color(0xFF2D5BFF); // Vibrant Blue
  static const Color _secondaryColor = Color(0xFF00C2FF); // Cyan accent
  static const Color _accentColor = Color(0xFF7B61FF); // Purple accent
  static const Color _successColor = Color(0xFF10B981); // Emerald Green
  static const Color _warningColor = Color(0xFFF59E0B); // Amber
  static const Color _errorColor = Color(0xFFEF4444); // Red
  static const Color _infoColor = Color(0xFF3B82F6); // Blue

  // Dark Theme Colors
  static const Color _bgDark = Color(0xFF0A0F1A); // Deep navy background
  static const Color _surfaceDark = Color(0xFF141A2A); // Card background
  static const Color _surfaceVariantDark = Color(0xFF1E2538); // Variant surface
  static const Color _onSurfaceDark = Color(0xFFE2E8F0); // Text on dark

  // Light Theme Colors
  static const Color _bgLight = Color(0xFFF8FAFC); // Very light blue-gray
  static const Color _surfaceLight = Colors.white; // Pure white cards
  static const Color _surfaceVariantLight = Color(
    0xFFF1F5F9,
  ); // Slightly off-white
  static const Color _onSurfaceLight = Color(0xFF1E293B); // Slate text

  // Custom Text Styles
  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: textColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: textColor.withOpacity(0.9),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor.withOpacity(0.8),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: textColor.withOpacity(0.7),
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor.withOpacity(0.8),
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor.withOpacity(0.7),
      ),
    );
  }

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _bgDark,
    colorScheme: ColorScheme.dark(
      primary: _primaryColor,
      primaryContainer: _primaryColor.withOpacity(0.2),
      secondary: _secondaryColor,
      secondaryContainer: _secondaryColor.withOpacity(0.2),
      surface: _surfaceDark,
      surfaceVariant: _surfaceVariantDark,
      background: _bgDark,
      error: _errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: _onSurfaceDark,
      onBackground: _onSurfaceDark,
      onError: Colors.white,
      outline: const Color(0xFF374151),
      outlineVariant: const Color(0xFF4B5563),
    ),
    textTheme: _buildTextTheme(ThemeData.dark().textTheme, _onSurfaceDark),

    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor: _surfaceDark,
      foregroundColor: _onSurfaceDark,
      centerTitle: false,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.1),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _onSurfaceDark,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: _surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.1),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1),
        foregroundColor: _primaryColor,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),

    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceVariantDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(color: _onSurfaceDark.withOpacity(0.5)),
      labelStyle: GoogleFonts.inter(color: _onSurfaceDark.withOpacity(0.8)),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: _surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _surfaceDark,
      selectedItemColor: _primaryColor,
      unselectedItemColor: _onSurfaceDark.withOpacity(0.6),
      elevation: 4,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: Colors.white.withOpacity(0.1),
      thickness: 1,
      space: 0,
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(

      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceDark,
      contentTextStyle: GoogleFonts.inter(color: _onSurfaceDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceVariantDark,
      selectedColor: _primaryColor.withOpacity(0.2),
      labelStyle: GoogleFonts.inter(color: _onSurfaceDark),
      secondaryLabelStyle: GoogleFonts.inter(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Progress Indicator
    progressIndicatorTheme: ProgressIndicatorThemeData(
      circularTrackColor: _surfaceVariantDark,
      color: _primaryColor,
      linearTrackColor: _surfaceVariantDark,
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _bgLight,
    colorScheme: ColorScheme.light(
      primary: _primaryColor,
      primaryContainer: _primaryColor.withOpacity(0.1),
      secondary: _secondaryColor,
      secondaryContainer: _secondaryColor.withOpacity(0.1),
      surface: _surfaceLight,
      surfaceVariant: _surfaceVariantLight,
      background: _bgLight,
      error: _errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: _onSurfaceLight,
      onBackground: _onSurfaceLight,
      onError: Colors.white,
      outline: const Color(0xFFE5E7EB),
      outlineVariant: const Color(0xFFD1D5DB),
    ),
    textTheme: _buildTextTheme(ThemeData.light().textTheme, _onSurfaceLight),

    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor: _surfaceLight,
      foregroundColor: _onSurfaceLight,
      centerTitle: false,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.05),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _onSurfaceLight,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: _surfaceLight,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
      ),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.05),
    ),

    // Buttons (same as dark with adjusted colors)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: _primaryColor.withOpacity(0.3), width: 1),
        foregroundColor: _primaryColor,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),

    // Input Fields (light version)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceVariantLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(color: _onSurfaceLight.withOpacity(0.5)),
      labelStyle: GoogleFonts.inter(color: _onSurfaceLight.withOpacity(0.8)),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: _surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _surfaceLight,
      selectedItemColor: _primaryColor,
      unselectedItemColor: _onSurfaceLight.withOpacity(0.6),
      elevation: 4,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: Colors.black.withOpacity(0.1),
      thickness: 1,
      space: 0,
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceLight,
      contentTextStyle: GoogleFonts.inter(color: _onSurfaceLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceVariantLight,
      selectedColor: _primaryColor.withOpacity(0.1),
      labelStyle: GoogleFonts.inter(color: _onSurfaceLight),
      secondaryLabelStyle: GoogleFonts.inter(color: _onSurfaceLight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Progress Indicator
    progressIndicatorTheme: ProgressIndicatorThemeData(
      circularTrackColor: _surfaceVariantLight,
      color: _primaryColor,
      linearTrackColor: _surfaceVariantLight,
    ),
  );

  // Custom theme extensions for easy access
  static Color get successColor => _successColor;
  static Color get warningColor => _warningColor;
  static Color get errorColor => _errorColor;
  static Color get infoColor => _infoColor;
  static Color get accentColor => _accentColor;
}
