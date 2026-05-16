import 'dart:ui';
import 'package:hash_wallet/themes/core/custom_theme_colors.dart';

class DarkThemeCustomColors extends CustomThemeColors {
  @override
  Color get warningContainerColor => const Color(0xFF8E5800);

  @override
  Color get warningOutlineColor => const Color(0xFFFFB84E);

  @override
  Color get backgroundMainColor => const Color(0xFF000000);

  @override
  Color get backgroundGradientColor => const Color(0xFF06150C);

  @override
  Color get cardGradientColorPrimary => const Color(0xFF1F4530);

  @override
  Color get cardGradientColorSecondary => const Color(0xFF112A1D);

  @override
  Color get toggleKnobStateColor => const Color(0xFFFFFFFF);

  @override
  Color get toggleColorOffState => const Color(0xFF2A5840);
}
