// [HEALTH APP] — Dashboard Summary Model
// Aggregated data object for the dashboard screen.

enum TDEEConfidence { building, calibrated, inconsistent }

class DashboardSummary {
  // Today's totals (from food_logs)
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFibre;

  // User's targets (from users table)
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final double targetFibre;

  // Streak
  final int currentStreak;

  // Weekly context
  final double weeklyCaloriesLogged;
  final double weeklyCaloriesTarget;
  final int weeklyDaysLogged;

  // TDEE calibration
  final TDEEConfidence tdeeConfidence;
  final int daysLoggedForCalibration; // 0–14

  // User info
  final String userName;
  final double bmi;
  final String goal;

  // Optional: new target after recalibration (for notification banner)
  final double? recalibratedTargetCalories;
  final bool hasNewCalibration;

  const DashboardSummary({
    this.totalCalories = 0,
    this.totalProtein = 0,
    this.totalCarbs = 0,
    this.totalFat = 0,
    this.totalFibre = 0,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.targetFibre,
    this.currentStreak = 0,
    this.weeklyCaloriesLogged = 0,
    this.weeklyCaloriesTarget = 0,
    this.weeklyDaysLogged = 0,
    this.tdeeConfidence = TDEEConfidence.building,
    this.daysLoggedForCalibration = 0,
    required this.userName,
    required this.bmi,
    required this.goal,
    this.recalibratedTargetCalories,
    this.hasNewCalibration = false,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0,
      totalFibre: (json['totalFibre'] as num?)?.toDouble() ?? 0,
      targetCalories: (json['targetCalories'] as num?)?.toDouble() ?? 2000,
      targetProtein: (json['targetProtein'] as num?)?.toDouble() ?? 150,
      targetCarbs: (json['targetCarbs'] as num?)?.toDouble() ?? 200,
      targetFat: (json['targetFat'] as num?)?.toDouble() ?? 55,
      targetFibre: (json['targetFibre'] as num?)?.toDouble() ?? 30,
      currentStreak: json['currentStreak'] as int? ?? 0,
      weeklyCaloriesLogged: (json['weeklyCaloriesLogged'] as num?)?.toDouble() ?? 0,
      weeklyCaloriesTarget: (json['weeklyCaloriesTarget'] as num?)?.toDouble() ?? 0,
      weeklyDaysLogged: json['weeklyDaysLogged'] as int? ?? 0,
      tdeeConfidence: TDEEConfidence.values.firstWhere(
        (e) => e.toString() == (json['tdeeConfidence'] as String?),
        orElse: () => TDEEConfidence.building,
      ),
      daysLoggedForCalibration: json['daysLoggedForCalibration'] as int? ?? 0,
      userName: json['userName'] as String? ?? 'User',
      bmi: (json['bmi'] as num?)?.toDouble() ?? 22.0,
      goal: json['goal'] as String? ?? 'maintain',
      recalibratedTargetCalories: (json['recalibratedTargetCalories'] as num?)?.toDouble(),
      hasNewCalibration: json['hasNewCalibration'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'totalFibre': totalFibre,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
      'targetFibre': targetFibre,
      'currentStreak': currentStreak,
      'weeklyCaloriesLogged': weeklyCaloriesLogged,
      'weeklyCaloriesTarget': weeklyCaloriesTarget,
      'weeklyDaysLogged': weeklyDaysLogged,
      'tdeeConfidence': tdeeConfidence.toString(),
      'daysLoggedForCalibration': daysLoggedForCalibration,
      'userName': userName,
      'bmi': bmi,
      'goal': goal,
      'recalibratedTargetCalories': recalibratedTargetCalories,
      'hasNewCalibration': hasNewCalibration,
    };
  }

  double get caloriesRemaining => targetCalories - totalCalories;
  bool get isOver => totalCalories > targetCalories;
  double get ringProgress =>
      (totalCalories / targetCalories).clamp(0.0, 1.0);
}
