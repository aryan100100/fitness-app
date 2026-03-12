// [HEALTH APP] — Premium UI Design System Colours
// Deep iOS-style dark mode palette.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Backgrounds ---
  // True black for modern OLED screens (iOS style)
  static const Color background = Color(0xFF000000);
  // Elevated surfaces (cards, bottom sheets)
  static const Color cardSurface = Color(0xFF141414);
  // Higher elevation (modals, dialogs, floating elements)
  static const Color elevatedCard = Color(0xFF1C1C1E);

  // --- Accents ---
  // A single vibrant accent color (Deep Premium Orange) analogous to the reference
  static const Color primaryAccent = Color(0xFFFF9F0A); // iOS System Orange
  static const Color secondaryAccent = Color(0xFFFFB340);

  // --- Status ---
  static const Color destructive = Color(0xFFFF453A); 
  static const Color warning = Color(0xFFFF9F0A);     
  static const Color info = Color(0xFF0A84FF);        

  // --- Text ---
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFA1A1A6); // Lighter, cleaner grey
  static const Color tertiaryText = Color(0xFF636366);

  // --- Dividers & Borders ---
  static const Color divider = Color(0xFF2C2C2E);     
  static const Color subtleBorder = Color(0xFF1C1C1E);

  // --- Macro bar colours (Monochromatic styling to reduce clutter) ---
  static const Color proteinBar = Color(0xFFE5E5EA); // Almost white
  static const Color carbBar = Color(0xFF8E8E93);    // Mid Grey
  static const Color fatBar = Color(0xFF48484A);     // Dark Grey

  // --- Shimmer Base Colors ---
  static const Color shimmerBase = Color(0xFF1C1C1E);
  static const Color shimmerHighlight = Color(0xFF2C2C2E);
}
