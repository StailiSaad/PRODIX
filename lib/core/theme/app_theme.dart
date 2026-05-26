import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Theme colors from Tailwind design
  static const Color bgColor = Color(0xFF0B1326); // surface
  static const Color cardColor = Color(0xFF171F33); // surface-container
  static const Color cardHighColor =
      Color(0xFF222A3D); // surface-container-high
  static const Color cardHighestColor =
      Color(0xFF2D3449); // surface-container-highest
  static const Color primaryColor = Color(0xFFD2BBFF); // primary
  static const Color primaryInverse = Color(0xFF732EE4); // inverse-primary
  static const Color secondaryColor = Color(0xFFB4C5FF); // secondary
  static const Color tertiaryColor = Color(0xFF4AE176); // tertiary
  static const Color textMain = Color(0xFFDAE2FD); // on-surface
  static const Color textVariant = Color(0xFFCCC3D8); // on-surface-variant
  static const Color errorColor = Color(0xFFFFB4AB); // error
  static const Color outlineColor = Color(0xFF958DA1); // outline
  // Aliases used across legacy pages
  static const Color textWhite = textMain;
  static const Color textGrey = textVariant;

  static ThemeData futuristicDark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: cardColor,
        error: errorColor,
        onSurface: textMain,
        onPrimary: Color(0xFF3F008E), // on-primary
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
          side: const BorderSide(color: cardHighestColor, width: 1),
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
          side: const BorderSide(color: primaryColor),
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
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textVariant),
        labelStyle: const TextStyle(color: textVariant),
        prefixIconColor: textVariant,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardHighestColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: cardHighestColor,
        thickness: 1,
      ),
    );
  }
}
