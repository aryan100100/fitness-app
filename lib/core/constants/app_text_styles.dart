// [HEALTH APP] — Typography Styles (Inter via Google Fonts)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get headingLarge => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryText,
      );

  static TextStyle get headingMedium => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryText,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.primaryText,
      );

  static TextStyle get bodySecondary => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.secondaryText,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: AppColors.secondaryText,
      );

  static TextStyle get captionAccent => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryAccent,
      );

  /// For large calorie / stat numbers — 36px+, bold, green
  static TextStyle get statsNumber => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryAccent,
      );

  static TextStyle get statsNumberLarge => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryAccent,
      );

  static TextStyle get buttonLabel => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryText,
      );
}
