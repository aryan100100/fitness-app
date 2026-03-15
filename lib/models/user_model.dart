// [HEALTH APP] — User Model
// Mirrors the `users` Supabase table exactly.
// Updated for Feature 1 Update: added proteinPreference, liftingExperience, proteinMultiplier.

class UserModel {
  final String? id;
  final String name;
  final int age;
  final String biologicalSex;       // 'male' | 'female'
  final double heightCm;
  final double weightKg;
  final double? targetWeightKg;
  final String goal;                 // 'lose' | 'gain' | 'maintain'
  final String activityLevel;        // 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active'
  final String lifeSituation;        // 'hostel_student' | 'office_worker' | 'work_from_home' | 'homemaker' | 'other'
  final String region;               // 'India' | 'USA' | 'UK' | 'Other'
  final double tdee;
  final double targetCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String? goalStartDate;       // yyyy-MM-dd
  final String? goalEndDate;         // yyyy-MM-dd
  final List<String> foodPreferences;
  final String? createdAt;

  // Feature 2 additions
  final String? bodyFatRange;        // e.g. '13-16' | null if skipped
  final double? weeklyPacePercent;   // e.g. 0.75 (stored as %, not decimal)
  final double? dailyDeficitSurplus; // negative = deficit, positive = surplus

  // Feature 1 Update additions
  final String proteinPreference;    // 'high' | 'moderate' | 'comfortable'
  final String? liftingExperience;   // 'none' | 'beginner' | 'intermediate' | 'advanced'
  final double? proteinMultiplier;   // final g/kg multiplier used, for reference

  // Feature 7 additions — auto adjustment tracking
  final bool goalDateReminderShown;
  final String? lastSituation3Prompt;     // yyyy-MM-dd
  final String? lastDivergenceCheck;      // yyyy-MM-dd
  final String? lastWeeklyRecalcDate;     // yyyy-MM-dd
  final double? previousWeeklyWeight;     // last week's 7-day average
  final double pendingTargetAdjustment;   // kcal held back for phased large change
  final int checkinDay;                   // 1 = Monday … 7 = Sunday (ISO)
  final bool lowPressureMode;
  final String weightUnit;                // 'kg' | 'lbs'

  // Feature 8 additions
  final int lowMotivationCount;
  final String? lastLowMotivationUse;
  final String? lastClinicalFlagShown;
  final bool hideStreakCounter;

  // Feature 9 additions — Progress Photos
  final bool progressPhotosEnabled;
  final bool progressPhotoReminderEnabled;
  final int progressPhotoReminderIntervalDays;
  final String? lastProgressPhotoReminder;
  final int progressPhotosComparisonStreak;
  final String? lastComparisonDate;

  const UserModel({
    this.id,
    required this.name,
    required this.age,
    required this.biologicalSex,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.goal,
    required this.activityLevel,
    required this.lifeSituation,
    this.region = 'India',
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    this.goalStartDate,
    this.goalEndDate,
    this.foodPreferences = const [],
    this.createdAt,
    this.bodyFatRange,
    this.weeklyPacePercent,
    this.dailyDeficitSurplus,
    this.proteinPreference = 'moderate',
    this.liftingExperience,
    this.proteinMultiplier,
    this.goalDateReminderShown = false,
    this.lastSituation3Prompt,
    this.lastDivergenceCheck,
    this.lastWeeklyRecalcDate,
    this.previousWeeklyWeight,
    this.pendingTargetAdjustment = 0,
    this.checkinDay = 1,
    this.lowPressureMode = false,
    this.weightUnit = 'kg',
    this.lowMotivationCount = 0,
    this.lastLowMotivationUse,
    this.lastClinicalFlagShown,
    this.hideStreakCounter = false,
    this.progressPhotosEnabled = false,
    this.progressPhotoReminderEnabled = false,
    this.progressPhotoReminderIntervalDays = 14,
    this.lastProgressPhotoReminder,
    this.progressPhotosComparisonStreak = 0,
    this.lastComparisonDate,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      biologicalSex: json['biological_sex'] as String? ?? 'male',
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      goal: json['goal'] as String? ?? 'maintain',
      activityLevel: json['activity_level'] as String? ?? 'sedentary',
      lifeSituation: json['life_situation'] as String? ?? 'other',
      region: json['region'] as String? ?? 'India',
      tdee: (json['tdee'] as num?)?.toDouble() ?? 0,
      targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0,
      goalStartDate: json['goal_start_date'] as String?,
      goalEndDate: json['goal_end_date'] as String?,
      foodPreferences: json['food_preferences'] != null
          ? List<String>.from(json['food_preferences'] as List)
          : [],
      createdAt: json['created_at'] as String?,
      bodyFatRange: json['body_fat_range'] as String?,
      weeklyPacePercent: (json['weekly_pace_percent'] as num?)?.toDouble(),
      dailyDeficitSurplus: (json['daily_deficit_surplus'] as num?)?.toDouble(),
      proteinPreference: json['protein_preference'] as String? ?? 'moderate',
      liftingExperience: json['lifting_experience'] as String?,
      proteinMultiplier: (json['protein_multiplier'] as num?)?.toDouble(),
      goalDateReminderShown: json['goal_date_reminder_shown'] as bool? ?? false,
      lastSituation3Prompt: json['last_situation3_prompt'] as String?,
      lastDivergenceCheck: json['last_divergence_check'] as String?,
      lastWeeklyRecalcDate: json['last_weekly_recalc_date'] as String?,
      previousWeeklyWeight: (json['previous_weekly_weight'] as num?)?.toDouble(),
      pendingTargetAdjustment: (json['pending_target_adjustment'] as num?)?.toDouble() ?? 0,
      checkinDay: (json['checkin_day'] as num?)?.toInt() ?? 1,
      lowPressureMode: json['low_pressure_mode'] as bool? ?? false,
      weightUnit: json['weight_unit'] as String? ?? 'kg',
      lowMotivationCount: (json['low_motivation_count'] as num?)?.toInt() ?? 0,
      lastLowMotivationUse: json['last_low_motivation_use'] as String?,
      lastClinicalFlagShown: json['last_clinical_flag_shown'] as String?,
      hideStreakCounter: json['hide_streak_counter'] as bool? ?? false,
      progressPhotosEnabled: json['progress_photos_enabled'] as bool? ?? false,
      progressPhotoReminderEnabled: json['progress_photo_reminder_enabled'] as bool? ?? false,
      progressPhotoReminderIntervalDays: (json['progress_photo_reminder_interval_days'] as num?)?.toInt() ?? 14,
      lastProgressPhotoReminder: json['last_progress_photo_reminder'] as String?,
      progressPhotosComparisonStreak: (json['progress_photos_comparison_streak'] as num?)?.toInt() ?? 0,
      lastComparisonDate: json['last_comparison_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'age': age,
      'biological_sex': biologicalSex,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      'goal': goal,
      'activity_level': activityLevel,
      'life_situation': lifeSituation,
      'region': region,
      'tdee': tdee,
      'target_calories': targetCalories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      if (goalStartDate != null) 'goal_start_date': goalStartDate,
      if (goalEndDate != null) 'goal_end_date': goalEndDate,
      'food_preferences': foodPreferences,
      if (bodyFatRange != null) 'body_fat_range': bodyFatRange,
      if (weeklyPacePercent != null) 'weekly_pace_percent': weeklyPacePercent,
      if (dailyDeficitSurplus != null) 'daily_deficit_surplus': dailyDeficitSurplus,
      'protein_preference': proteinPreference,
      if (liftingExperience != null) 'lifting_experience': liftingExperience,
      if (proteinMultiplier != null) 'protein_multiplier': proteinMultiplier,
      'goal_date_reminder_shown': goalDateReminderShown,
      if (lastSituation3Prompt != null) 'last_situation3_prompt': lastSituation3Prompt,
      if (lastDivergenceCheck != null) 'last_divergence_check': lastDivergenceCheck,
      if (lastWeeklyRecalcDate != null) 'last_weekly_recalc_date': lastWeeklyRecalcDate,
      if (previousWeeklyWeight != null) 'previous_weekly_weight': previousWeeklyWeight,
      'pending_target_adjustment': pendingTargetAdjustment,
      'checkin_day': checkinDay,
      'low_pressure_mode': lowPressureMode,
      'weight_unit': weightUnit,
      'low_motivation_count': lowMotivationCount,
      if (lastLowMotivationUse != null) 'last_low_motivation_use': lastLowMotivationUse,
      if (lastClinicalFlagShown != null) 'last_clinical_flag_shown': lastClinicalFlagShown,
      'hide_streak_counter': hideStreakCounter,
      'progress_photos_enabled': progressPhotosEnabled,
      'progress_photo_reminder_enabled': progressPhotoReminderEnabled,
      'progress_photo_reminder_interval_days': progressPhotoReminderIntervalDays,
      if (lastProgressPhotoReminder != null) 'last_progress_photo_reminder': lastProgressPhotoReminder,
      'progress_photos_comparison_streak': progressPhotosComparisonStreak,
      if (lastComparisonDate != null) 'last_comparison_date': lastComparisonDate,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    int? age,
    String? biologicalSex,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    String? goal,
    String? activityLevel,
    String? lifeSituation,
    String? region,
    double? tdee,
    double? targetCalories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    String? goalStartDate,
    String? goalEndDate,
    List<String>? foodPreferences,
    String? bodyFatRange,
    double? weeklyPacePercent,
    double? dailyDeficitSurplus,
    String? proteinPreference,
    String? liftingExperience,
    double? proteinMultiplier,
    bool? goalDateReminderShown,
    String? lastSituation3Prompt,
    String? lastDivergenceCheck,
    String? lastWeeklyRecalcDate,
    double? previousWeeklyWeight,
    double? pendingTargetAdjustment,
    int? checkinDay,
    bool? lowPressureMode,
    String? weightUnit,
    int? lowMotivationCount,
    String? lastLowMotivationUse,
    String? lastClinicalFlagShown,
    bool? hideStreakCounter,
    bool? progressPhotosEnabled,
    bool? progressPhotoReminderEnabled,
    int? progressPhotoReminderIntervalDays,
    String? lastProgressPhotoReminder,
    int? progressPhotosComparisonStreak,
    String? lastComparisonDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      lifeSituation: lifeSituation ?? this.lifeSituation,
      region: region ?? this.region,
      tdee: tdee ?? this.tdee,
      targetCalories: targetCalories ?? this.targetCalories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      goalStartDate: goalStartDate ?? this.goalStartDate,
      goalEndDate: goalEndDate ?? this.goalEndDate,
      foodPreferences: foodPreferences ?? this.foodPreferences,
      bodyFatRange: bodyFatRange ?? this.bodyFatRange,
      weeklyPacePercent: weeklyPacePercent ?? this.weeklyPacePercent,
      dailyDeficitSurplus: dailyDeficitSurplus ?? this.dailyDeficitSurplus,
      proteinPreference: proteinPreference ?? this.proteinPreference,
      liftingExperience: liftingExperience ?? this.liftingExperience,
      proteinMultiplier: proteinMultiplier ?? this.proteinMultiplier,
      goalDateReminderShown: goalDateReminderShown ?? this.goalDateReminderShown,
      lastSituation3Prompt: lastSituation3Prompt ?? this.lastSituation3Prompt,
      lastDivergenceCheck: lastDivergenceCheck ?? this.lastDivergenceCheck,
      lastWeeklyRecalcDate: lastWeeklyRecalcDate ?? this.lastWeeklyRecalcDate,
      previousWeeklyWeight: previousWeeklyWeight ?? this.previousWeeklyWeight,
      pendingTargetAdjustment: pendingTargetAdjustment ?? this.pendingTargetAdjustment,
      checkinDay: checkinDay ?? this.checkinDay,
      lowPressureMode: lowPressureMode ?? this.lowPressureMode,
      weightUnit: weightUnit ?? this.weightUnit,
      lowMotivationCount: lowMotivationCount ?? this.lowMotivationCount,
      lastLowMotivationUse: lastLowMotivationUse ?? this.lastLowMotivationUse,
      lastClinicalFlagShown: lastClinicalFlagShown ?? this.lastClinicalFlagShown,
      hideStreakCounter: hideStreakCounter ?? this.hideStreakCounter,
      progressPhotosEnabled: progressPhotosEnabled ?? this.progressPhotosEnabled,
      progressPhotoReminderEnabled: progressPhotoReminderEnabled ?? this.progressPhotoReminderEnabled,
      progressPhotoReminderIntervalDays: progressPhotoReminderIntervalDays ?? this.progressPhotoReminderIntervalDays,
      lastProgressPhotoReminder: lastProgressPhotoReminder ?? this.lastProgressPhotoReminder,
      progressPhotosComparisonStreak: progressPhotosComparisonStreak ?? this.progressPhotosComparisonStreak,
      lastComparisonDate: lastComparisonDate ?? this.lastComparisonDate,
    );
  }
}
