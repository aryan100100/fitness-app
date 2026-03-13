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

  // Low motivation feature
  final bool isMinimumViableDay;

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
    this.isMinimumViableDay = false,
  });

  double get caloriesRemaining => targetCalories - totalCalories;
  bool get isOver => totalCalories > targetCalories;
  double get ringProgress =>
      (totalCalories / targetCalories).clamp(0.0, 1.0);
}
