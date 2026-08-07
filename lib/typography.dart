import 'package:hash_wallet/utils/feature_flag.dart';
import 'package:flutter/material.dart';

const latoFont = "Lato";
const wixFont = "Wix Madefor Text";

TextStyle textXxSmall({Color? color}) => _hashRegular(10, color);

TextStyle textXxSmallSemiBold({Color? color}) => _hashSemiBold(10, color);

TextStyle textXSmall({Color? color}) => _hashRegular(12, color);

TextStyle textXSmallSemiBold({Color? color}) => _hashSemiBold(12, color);

TextStyle textSmall({Color? color}) => _hashRegular(14, color);

TextStyle textSmallSemiBold({Color? color}) => _hashSemiBold(14, color);

TextStyle textMedium({Color? color}) => _hashRegular(16, color);

TextStyle textMediumBold({Color? color}) => _hashBold(16, color);

TextStyle textMediumSemiBold({Color? color}) => _hashSemiBold(22, color);

TextStyle textLarge({Color? color}) => _hashRegular(18, color);

TextStyle textLargeBold({Color? color}) => _hashBold(18, color);

TextStyle textLargeSemiBold({Color? color}) => _hashSemiBold(24, color);

TextStyle textXLarge({Color? color}) => _hashRegular(32, color);

TextStyle textXLargeSemiBold({Color? color}) => _hashSemiBold(32, color);

TextStyle _hashRegular(double size, Color? color) => _textStyle(
      size: size,
      fontWeight: FontWeight.normal,
      color: color,
    );

TextStyle _hashBold(double size, Color? color) => _textStyle(
      size: size,
      fontWeight: FontWeight.w900,
      color: color,
    );

TextStyle _hashSemiBold(double size, Color? color) => _textStyle(
      size: size,
      fontWeight: FontWeight.w700,
      color: color,
    );

TextStyle _textStyle({
  required double size,
  required FontWeight fontWeight,
  Color? color,
}) =>
    TextStyle(
      fontFamily: FeatureFlag.hasNewUi ? wixFont : latoFont,
      fontSize: size,
      fontWeight: fontWeight,
      color: color ?? Colors.white,
    );
