import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VaultKey Design System faithfully matching the Google Stitch specification.
class AppTheme {
  // Light Mode Color Tokens
  static const Color primary = Color(0xFF1E40AF); // Royal Indigo
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF00288E);
  static const Color onPrimaryContainer = Color(0xFFA8B8FF);

  static const Color secondary = Color(0xFF0D9488); // Deep Sea Pine
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryFixed = Color(0xFF86F2E4);
  static const Color onSecondaryFixed = Color(0xFF00201D);

  static const Color tertiary = Color(0xFFD97706); // Warm Amber
  static const Color tertiaryFixed = Color(0xFFFFDDB8);
  static const Color onTertiaryFixed = Color(0xFF2A1700);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFF8F9FF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightContainerLow = Color(0xFFEFF4FF);
  static const Color lightContainer = Color(0xFFE5EEFF);
  static const Color lightContainerHigh = Color(0xFFDCE9FF);
  static const Color lightTextPrimary = Color(0xFF0B1C30);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightOutline = Color(0xFFE2E8F0);

  // Dark Mode Color Tokens (Enhanced for accessibility & high contrast)
  static const Color darkPrimary = Color(0xFF60A5FA); // Sky Blue 400 (Vibrant, accessible)
  static const Color darkOnPrimary = Color(0xFF0B1C30);
  static const Color darkPrimaryContainer = Color(0xFF1E3A8A);
  static const Color darkOnPrimaryContainer = Color(0xFFDBEAFE);

  static const Color darkSecondary = Color(0xFF2DD4BF); // Mint Cyan 400 (High contrast)
  static const Color darkOnSecondary = Color(0xFF00201D);

  static const Color darkTertiary = Color(0xFFFBBF24); // Amber Gold 400 (High contrast)
  static const Color darkOnTertiary = Color(0xFF2A1700);

  static const Color darkBackground = Color(0xFF0B1C30);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkContainerLow = Color(0xFF172554);
  static const Color darkContainer = Color(0xFF1E293B);
  static const Color darkContainerHigh = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextMuted = Color(0xFFCBD5E1); // Slate 300 for crisp readability
  static const Color darkOutline = Color(0xFF3B4D68); // Elevated border for dark mode

  // Adaptive Color Helpers
  static Color getPrimary(bool isDark) => isDark ? darkPrimary : primary;
  static Color getSecondary(bool isDark) => isDark ? darkSecondary : secondary;
  static Color getTertiary(bool isDark) => isDark ? darkTertiary : tertiary;
  static Color getTextPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color getTextMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;

  // Corner Radii
  static const double radiusCard = 16.0;
  static const double radiusInput = 16.0;
  static const double radiusButton = 16.0;
  static const double radiusIcon = 12.0;
  static const double radiusSheet = 24.0;

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: lightTextPrimary,
      displayColor: lightTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        error: error,
        onError: onError,
        outline: lightOutline,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: lightOutline, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: lightTextMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: lightTextMuted,
          fontSize: 14,
        ),
        prefixIconColor: lightTextMuted,
        suffixIconColor: lightTextMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: lightOutline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: lightOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: textTheme,
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: darkTextPrimary, displayColor: darkTextPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        tertiary: darkTertiary,
        onTertiary: darkOnTertiary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        outline: darkOutline,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: darkOutline, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: darkOutline, width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: darkTextMuted,
          fontSize: 14,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: darkPrimary,
        labelColor: darkPrimary,
        unselectedLabelColor: darkTextMuted,
        labelStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        modalBackgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: darkTextMuted,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: darkTextMuted,
          fontSize: 14,
        ),
        prefixIconColor: darkTextMuted,
        suffixIconColor: darkTextMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: darkOutline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: darkOutline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkOnPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textTheme: textTheme,
    );
  }

  /// Monospace text style for passwords, codes, and recovery phrases using JetBrains Mono.
  static TextStyle monoStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.04,
    );
  }
}
