import 'package:flutter/material.dart';
import 'package:cake_wallet/themes/core/material_base_theme.dart';
import 'package:cake_wallet/themes/core/custom_theme_colors.dart';
import 'package:cake_wallet/themes/custom_theme_colors/light_theme_custom_colors.dart';

class LightTheme extends MaterialThemeBase {
  @override
  Brightness get brightness => Brightness.light;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  // Hash Wallet palette:
  //  - Primary: brand green (#1A5C38)
  //  - Secondary: Such Software pink (#B83278)
  //  - Tertiary: Such Software blue (#1F7DBF)
  //  - Surface: very light minty bg (#F2F8F4)
  @override
  Color get primaryColor => const Color(0xFF1A5C38);

  @override
  Color get secondaryColor => const Color(0xFFB83278);

  @override
  Color get tertiaryColor => const Color(0xFF1F7DBF);

  @override
  Color get errorColor => const Color(0xFFBA1A1A);

  @override
  Color get surfaceColor => const Color(0xFFF2F8F4);

  @override
  ColorScheme get colorScheme => ColorScheme.light(
        primary: primaryColor,
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFC7E5D2),
        onPrimaryContainer: const Color(0xFF0B1F14),
        secondary: secondaryColor,
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFF9D6E5),
        onSecondaryContainer: const Color(0xFF4A0E2C),
        tertiary: tertiaryColor,
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFD6EAF6),
        onTertiaryContainer: const Color(0xFF0B2C46),
        error: errorColor,
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFFFBDBD),
        onErrorContainer: const Color(0xFFE43D3D),
        surface: surfaceColor,
        surfaceDim: const Color(0xFFDDEBE3),
        onSurface: const Color(0xFF0B1F14),
        onSurfaceVariant: const Color(0xFF5A6B61),
        surfaceContainerLowest: Color(0xFFE2EEE7),
        surfaceContainerLow: Color(0xFFEAF2EC),
        surfaceContainer: Color(0xFFF5FAF6),
        surfaceContainerHigh: Color(0xFFFAFDFB),
        surfaceContainerHighest: Color(0xFFFFFFFF),
        onInverseSurface: Color(0xFFFAFAFA),
        outline: const Color(0xFF6F857A),
        outlineVariant: const Color(0xFFD9E6DE),
      );

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
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colorScheme.onSurface,
        ),
      );

  static const String fontFamily = 'Wix Madefor Text';
  @override
  ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: colorScheme,
        fontFamily: fontFamily,
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
        ),
      );

  @override
  String get title => 'Light Theme';

  @override
  ThemeType get type => ThemeType.light;

  @override
  int get raw => 0;

  @override
  CustomThemeColors get customColors => LightThemeCustomColors();

  @override
  String? get themeFamily => null;

  @override
  String? get accentColorId => null;

  @override
  String? get accentColorName => null;
}
