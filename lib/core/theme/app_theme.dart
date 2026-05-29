import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static bool _isLight = false;

  static void setBrightness(Brightness brightness) {
    _isLight = brightness == Brightness.light;
  }

  static bool get isLight => _isLight;

  // Theme colors (auto-adapt to light/dark)
  static Color get bgColor => _isLight ? const Color(0xFFF8F9FA) : const Color(0xFF0B1326);
  static Color get cardColor => _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF171F33);
  static Color get cardHighColor => _isLight ? const Color(0xFFF0EEF2) : const Color(0xFF222A3D);
  static Color get cardHighestColor => _isLight ? const Color(0xFFE4D9FF) : const Color(0xFF2D3449);
  static Color get primaryColor => _isLight ? const Color(0xFF7C3AED) : const Color(0xFFD2BBFF);
  static Color get primaryInverse => _isLight ? const Color(0xFFD2BBFF) : const Color(0xFF732EE4);
  static Color get secondaryColor => _isLight ? const Color(0xFF6366F1) : const Color(0xFFB4C5FF);
  static Color get tertiaryColor => _isLight ? const Color(0xFF10B981) : const Color(0xFF4AE176);
  static Color get textMain => _isLight ? const Color(0xFF1E1B2E) : const Color(0xFFDAE2FD);
  static Color get textVariant => _isLight ? const Color(0xFF6B6378) : const Color(0xFFCCC3D8);
  static Color get errorColor => _isLight ? const Color(0xFFDC2626) : const Color(0xFFFFB4AB);
  static Color get outlineColor => _isLight ? const Color(0xFF9C92AC) : const Color(0xFF958DA1);
  static Color get textWhite => textMain;
  static Color get textGrey => textVariant;

  static ThemeData futuristicDark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: cardColor,
        error: errorColor,
        onSurface: textMain,
        onPrimary: const Color(0xFF3F008E), // on-primary
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: textMain, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: textMain, fontWeight: FontWeight.w800),
        displaySmall: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: textMain, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: textMain, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: textMain, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: textMain,
            fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: textMain,
            fontWeight: FontWeight.normal),
        labelLarge: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: textMain,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.sora().fontFamily,
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardHighestColor, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF3F008E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardHighColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: textVariant),
        labelStyle: TextStyle(color: textVariant),
        prefixIconColor: textVariant,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardHighestColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: cardHighestColor,
        thickness: 1,
      ),
    );
  }

  static ThemeData futuristicLight() {
    const lightBg = Color(0xFFF8F9FA);
    const lightSurface = Color(0xFFFFFFFF);
    const lightPrimary = Color(0xFF7C3AED);
    const lightText = Color(0xFF1E1B2E);
    const lightTextSecondary = Color(0xFF8B8794);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: Color(0xFF6366F1),
        tertiary: Color(0xFF10B981),
        surface: lightSurface,
        error: Color(0xFFDC2626),
        onSurface: lightText,
        onPrimary: Color(0xFFFFFFFF),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: lightText, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: lightText, fontWeight: FontWeight.w800),
        displaySmall: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: lightText, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: lightText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            fontFamily: GoogleFonts.sora().fontFamily, color: lightText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: lightText,
            fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: lightText,
            fontWeight: FontWeight.normal),
        labelLarge: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: lightText,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.sora().fontFamily,
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: lightText),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0EEF2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
        labelStyle: const TextStyle(color: lightTextSecondary),
        prefixIconColor: lightTextSecondary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }

  static ThemeData glassmorphism() {
    const glassBg = Color(0xFF0D0A1A);
    const glassCard = Color(0x26FFFFFF);
    const glassBorder = Color(0x33FFFFFF);
    const glassGold = Color(0xFFD4AF37);
    const glassText = Color(0xFFF0EDF5);
    const glassTextSecondary = Color(0xFFA89FBA);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: glassBg,
      primaryColor: glassGold,
      colorScheme: const ColorScheme.dark(
        primary: glassGold,
        secondary: Color(0xFFA78BFA),
        tertiary: Color(0xFFF472B6),
        surface: glassCard,
        error: Color(0xFFFB7185),
        onSurface: glassText,
        onPrimary: Color(0xFF1A1425),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily, color: glassText, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily, color: glassText, fontWeight: FontWeight.w800),
        displaySmall: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily, color: glassText, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily, color: glassText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            fontFamily: GoogleFonts.playfairDisplay().fontFamily, color: glassText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: glassText,
            fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: glassText,
            fontWeight: FontWeight.normal),
        labelLarge: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            color: glassText,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.playfairDisplay().fontFamily,
          color: glassText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: glassText),
      ),
      cardTheme: CardThemeData(
        color: glassCard,
        elevation: 0,
        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: glassBorder, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: glassGold,
          foregroundColor: const Color(0xFF1A1425),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: glassGold,
          side: BorderSide(color: glassGold.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.inter().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassGold, width: 2),
        ),
        hintStyle: const TextStyle(color: glassTextSecondary),
        labelStyle: const TextStyle(color: glassTextSecondary),
        prefixIconColor: glassTextSecondary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: glassGold,
        unselectedItemColor: glassTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 1,
      ),
    );
  }
}
