// [HEALTH APP] — Streak Model (Feature 8)
// Models the streaks table with grace day logic.

class StreakModel {
  final String userId;
  final int currentStreak;
  final String? lastLogDate;
  final int graceDaysUsedThisWindow;
  final String? lastGraceDay;
  final int longestStreak;
  final bool streakHidden;

  const StreakModel({
    required this.userId,
    required this.currentStreak,
    this.lastLogDate,
    required this.graceDaysUsedThisWindow,
    this.lastGraceDay,
    required this.longestStreak,
    required this.streakHidden,
  });

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      userId: json['user_id'] as String,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      lastLogDate: json['last_log_date'] as String?,
      graceDaysUsedThisWindow: (json['grace_days_used_this_window'] as num?)?.toInt() ?? 0,
      lastGraceDay: json['last_grace_day'] as String?,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      streakHidden: json['streak_hidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'current_streak': currentStreak,
      if (lastLogDate != null) 'last_log_date': lastLogDate,
      'grace_days_used_this_window': graceDaysUsedThisWindow,
      if (lastGraceDay != null) 'last_grace_day': lastGraceDay,
      'longest_streak': longestStreak,
      'streak_hidden': streakHidden,
    };
  }
}
