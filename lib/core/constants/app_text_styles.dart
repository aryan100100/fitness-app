// [HEALTH APP] — Premium Typography Styles (Inter)
// Tighter letter spacing, bolder weights for a modern tech feel.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Large hero numbers (e.g. daily calories)
  static TextStyle get statsNumberLarge => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -2.0,
        color: AppColors.primaryText,
      );

  // Standard stats numbers
  static TextStyle get statsNumber => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        letterSpacing: -1.5,
        color: AppColors.primaryText,
      );

  // Page titles
  static TextStyle get headingLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -1.0,
        color: AppColors.primaryText,
      );

  // Section titles or card headers
  static TextStyle get headingMedium => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.primaryText,
      );

  static TextStyle get headingSmall => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.primaryText,
      );

  // Standard body text
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: AppColors.primaryText,
      );

  // Secondary body text (descriptions, subtitles)
  static TextStyle get bodySecondary => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: AppColors.secondaryText,
      );

  // Small labels, hints, footnotes
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.secondaryText,
      );

  // Small emphasized labels
  static TextStyle get captionAccent => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.primaryAccent,
      );

  // Bold buttons
  static TextStyle get buttonLabel => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.primaryText, // Will be overridden to black/bg mostly
      );
}
