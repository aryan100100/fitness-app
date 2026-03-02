// [HEALTH APP] — Design System Colours
// Single source of truth. Import this in every screen.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Backgrounds ---
  static const Color background = Color(0xFF0D0D0D);
  static const Color cardSurface = Color(0xFF1A1A1A);
  static const Color elevatedCard = Color(0xFF222222);

  // --- Accents ---
  static const Color primaryAccent = Color(0xFF00C853);
  static const Color secondaryAccent = Color(0xFF69F0AE);

  // --- Status ---
  static const Color destructive = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);

  // --- Text ---
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFF9E9E9E);

  // --- Dividers ---
  static const Color divider = Color(0xFF2A2A2A);

  // --- Macro bar colours ---
  static const Color proteinBar = Color(0xFF00C853); // green
  static const Color carbBar = Color(0xFF448AFF);    // blue
  static const Color fatBar = Color(0xFFFF9100);     // orange
}
