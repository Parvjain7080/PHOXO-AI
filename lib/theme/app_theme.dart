import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the app's "sleek minimal / dark glass" identity.
///
/// Two accents only:
///  - [signalBlue]  -> primary accent, used for on-device / local-model state
///  - [brass]       -> secondary accent, used sparingly for remote/laptop-GPU
///                     state and small premium touches. Never both at once
///                     in the same component.
class AppColors {
  AppColors._();

  // Dark theme base
  static const obsidian = Color(0xFF0A0C10);
  static const steel = Color(0xFF12151B);
  static const steelBorder = Color(0x1FFFFFFF); // white @ 12%
  static const glassFillDark = Color(0x0AFFFFFF); // white @ 4%

  // Light theme base
  static const mist = Color(0xFFF6F7F9);
  static const cloud = Color(0xFFFFFFFF);
  static const cloudBorder = Color(0xFFD8DCE3);
  static const glassFillLight = Color(0x99FFFFFF); // white @ 60%

  // Accents
  static const signalBlueDark = Color(0xFF5B8CFF);
  static const signalBlueLight = Color(0xFF3D6FE0);
  static const brassDark = Color(0xFFC9A227);
  static const brassLight = Color(0xFFA8790E);

  // Text
  static const inkDark = Color(0xFFE8EAED); // primary text on dark
  static const inkDarkSecondary = Color(0xFF9AA4B2);
  static const inkLight = Color(0xFF14171C); // primary text on light
  static const inkLightSecondary = Color(0xFF5B6472);

  static const error = Color(0xFFE5484D);
}

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color primaryText, Color secondaryText) {
    final base = GoogleFonts.interTextTheme();
    final display = GoogleFonts.spaceGroteskTextTheme();

    return base
        .copyWith(
          headlineLarge: display.headlineLarge?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          headlineMedium: display.headlineMedium?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          titleLarge: display.titleLarge?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.titleMedium?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: base.bodyLarge?.copyWith(color: primaryText, height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(
            color: primaryText,
            height: 1.4,
          ),
          bodySmall: base.bodySmall?.copyWith(color: secondaryText),
          labelLarge: base.labelLarge?.copyWith(color: primaryText),
          labelMedium: base.labelMedium?.copyWith(color: secondaryText),
        )
        .apply(bodyColor: primaryText, displayColor: primaryText);
  }

  static ThemeData get dark {
    const primaryText = AppColors.inkDark;
    const secondaryText = AppColors.inkDarkSecondary;

    final colorScheme = const ColorScheme.dark().copyWith(
      brightness: Brightness.dark,
      surface: AppColors.steel,
      onSurface: primaryText,
      primary: AppColors.signalBlueDark,
      onPrimary: AppColors.obsidian,
      secondary: AppColors.brassDark,
      onSecondary: AppColors.obsidian,
      error: AppColors.error,
      outline: AppColors.steelBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.obsidian,
      colorScheme: colorScheme,
      textTheme: _textTheme(primaryText, secondaryText),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: primaryText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassFillDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.steelBorder),
        ),
      ),
      dividerColor: AppColors.steelBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFillDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.steelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.steelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: AppColors.signalBlueDark,
            width: 1.4,
          ),
        ),
        hintStyle: const TextStyle(color: secondaryText),
      ),
      iconTheme: const IconThemeData(color: primaryText),
    );
  }

  static ThemeData get light {
    const primaryText = AppColors.inkLight;
    const secondaryText = AppColors.inkLightSecondary;

    final colorScheme = const ColorScheme.light().copyWith(
      brightness: Brightness.light,
      surface: AppColors.cloud,
      onSurface: primaryText,
      primary: AppColors.signalBlueLight,
      onPrimary: Colors.white,
      secondary: AppColors.brassLight,
      onSecondary: Colors.white,
      error: AppColors.error,
      outline: AppColors.cloudBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.mist,
      colorScheme: colorScheme,
      textTheme: _textTheme(primaryText, secondaryText),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: primaryText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassFillLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.cloudBorder),
        ),
      ),
      dividerColor: AppColors.cloudBorder,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFillLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.cloudBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.cloudBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: AppColors.signalBlueLight,
            width: 1.4,
          ),
        ),
        hintStyle: const TextStyle(color: secondaryText),
      ),
      iconTheme: const IconThemeData(color: primaryText),
    );
  }
}