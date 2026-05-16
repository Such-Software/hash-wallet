import 'package:flutter/material.dart';
import 'package:hash_wallet/themes/core/material_base_theme.dart';
import 'package:hash_wallet/themes/core/custom_theme_colors.dart';
import 'package:hash_wallet/themes/custom_theme_colors/dark_theme_custom_colors.dart';

class DarkTheme extends MaterialThemeBase {
  @override
  Brightness get brightness => Brightness.dark;

  @override
  ThemeMode get themeMode => ThemeMode.dark;

  // Hash Wallet dark palette:
  //  - Primary: mint (#7FCAA0) — light enough to read on dark surface
  //  - Secondary: soft pink (#E16FA6)
  //  - Tertiary: soft blue (#6AB7E6)
  //  - Surface: deep green (#0B1F14)
  @override
  Color get primaryColor => const Color(0xFF7FCAA0);

  @override
  Color get secondaryColor => const Color(0xFFE16FA6);

  @override
  Color get errorColor => const Color(0xFFFFB4AB);

  @override
  Color get surfaceColor => const Color(0xFF0B1F14);

  @override
  Color get tertiaryColor => const Color(0xFF6AB7E6);

  @override
  ColorScheme get colorScheme => ColorScheme.dark(
        primary: primaryColor,
        onPrimary: const Color(0xFF0B1F14),
        primaryContainer: const Color(0xFF1A5C38),
        onPrimaryContainer: const Color(0xFFC7E5D2),
        secondary: secondaryColor,
        onSecondary: const Color(0xFF3A0F22),
        secondaryContainer: const Color(0xFF7A1F4E),
        onSecondaryContainer: const Color(0xFFFAD5E5),
        tertiary: tertiaryColor,
        onTertiary: const Color(0xFF0B2C46),
        tertiaryContainer: const Color(0xFF14507A),
        onTertiaryContainer: const Color(0xFFD6EAF6),
        error: errorColor,
        onError: const Color(0xFFB71919),
        errorContainer: const Color(0xFFC53636),
        onErrorContainer: const Color(0xFFFFDAD6),
        surface: surfaceColor,
        onSurface: const Color(0xFFE0F0E8),
        surfaceDim: const Color(0xFF06150C),
        onSurfaceVariant: const Color(0xFF9BB5A6),
        surfaceContainerLowest: Color(0xFF06150C),
        surfaceContainerLow: Color(0xFF112A1D),
        surfaceContainer: Color(0xFF173524),
        surfaceContainerHigh: Color(0xFF1F4530),
        surfaceContainerHighest: Color(0xFF2A5840),
        outline: const Color(0xFF8AAA98),
        outlineVariant: const Color(0xFF1F4530),
      );
  static const String fontFamily = 'Wix Madefor Text';
  @override
  TextTheme get textTheme => TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: colorScheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colorScheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: colorScheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: colorScheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: colorScheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colorScheme.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colorScheme.onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colorScheme.onSurface,
        ),
      );

  @override
  ThemeData get themeData => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        brightness: brightness,
        colorScheme: colorScheme,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainer,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.error),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      );

  @override
  String get title => 'Dark Theme';

  @override
  ThemeType get type => ThemeType.dark;

  @override
  int get raw => 1;

  @override
  CustomThemeColors get customColors => DarkThemeCustomColors();

  @override
  String? get themeFamily => null;

  @override
  String? get accentColorId => null;

  @override
  String? get accentColorName => null;
}
