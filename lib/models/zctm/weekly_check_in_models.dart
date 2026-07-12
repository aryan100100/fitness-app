// [ZCTM] — Weekly Check-In Models
// Input/output for the weekly check-in summary Gemini call.

/// Data sent to Gemini for the personalised weekly check-in summary.
class WeeklyCheckInInput {
  final String userName;
  final double weightStart;          // kg (internal storage)
  final double weightEnd;            // kg
  final String weightUnit;           // 'kg' | 'lbs' — for display in response
  final bool isMenstrualWeek;
  final int proteinAdherenceDays;    // days where ≥80% of protein target was met
  final int totalLoggedDays;
  final double proteinTargetG;
  final double averageProteinG;      // average across logged days
  final int weekNumber;              // e.g., week 4 of the plan

  const WeeklyCheckInInput({
    required this.userName,
    required this.weightStart,
    required this.weightEnd,
    required this.weightUnit,
    required this.isMenstrualWeek,
    required this.proteinAdherenceDays,
    required this.totalLoggedDays,
    required this.proteinTargetG,
    required this.averageProteinG,
    required this.weekNumber,
  });

  Map<String, dynamic> toJson() => {
        'user_name': userName,
        'weight_start': weightStart,
        'weight_end': weightEnd,
        'weight_unit': weightUnit,
        'is_menstrual_week': isMenstrualWeek,
        'protein_adherence_days': proteinAdherenceDays,
        'total_logged_days': totalLoggedDays,
        'protein_target_g': proteinTargetG,
        'average_protein_g': averageProteinG,
        'week_number': weekNumber,
      };
}

/// Three-sentence personalised summary returned by Gemini.
/// Sentence 1: weight trend. Sentence 2: protein adherence. Sentence 3: focus.
class WeeklyCheckInSummary {
  final String summary; // Three sentences joined as a single string.

  const WeeklyCheckInSummary({required this.summary});

  factory WeeklyCheckInSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyCheckInSummary(
      summary: json['summary'] as String? ?? '',
    );
  }
}
