// [HEALTH APP] — Date Helper Utilities

class DateHelpers {
  DateHelpers._();

  /// Returns age in years from a date of birth.
  static int ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Returns a yyyy-MM-dd string for Supabase date fields.
  static String toDateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Returns today's date as a yyyy-MM-dd string.
  static String todayString() => toDateString(DateTime.now());

  /// Returns how many days remain until a target date.
  static int daysUntil(DateTime target) {
    final now = DateTime.now();
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Returns the number of remaining days in the current week (Mon–Sun).
  static int remainingDaysInWeek() {
    final now = DateTime.now();
    // weekday: 1=Mon, 7=Sun
    return 7 - now.weekday;
  }
}
