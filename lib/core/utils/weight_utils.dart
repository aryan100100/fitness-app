// Weight display utilities.
// Internal storage is always kg. Use these helpers for all user-facing labels.

/// Returns a display-ready string with value + unit label.
/// [weightKg] is the value as stored internally (always kg).
/// [unit] is the user's preferred unit from users.weight_unit — 'kg' or 'lbs'.
String formatWeight(double weightKg, String unit) {
  if (unit == 'lbs') {
    final lbs = weightKg * 2.20462;
    return '${lbs.toStringAsFixed(1)} lbs';
  }
  return '${weightKg.toStringAsFixed(1)} kg';
}

/// Returns just the unit label string — 'lbs' or 'kg'.
String weightUnitLabel(String unit) => unit == 'lbs' ? 'lbs' : 'kg';
