// [HEALTH APP] — TDEE + Macro + Nutrition Calculator Engine
// Pure Dart — no Flutter imports. Reusable from any screen or service.
// Updated for Feature 2: body fat modifier, pace slider, NutritionPlan.

import '../../models/user_model.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class MacroTargets {
  final double protein; // grams
  final double fat;     // grams
  final double carbs;   // grams
  final double fiber;   // grams
  final double sodiumMg;
  final double sugarG;
  /// True if carbs were clamped to 0 due to extreme calorie constraint.
  final bool carbWarning;
  /// Final g/kg protein multiplier used (after BF table + preference + clamp).
  final double proteinMultiplier;

  const MacroTargets({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
    required this.sodiumMg,
    required this.sugarG,
    this.carbWarning = false,
    required this.proteinMultiplier,
  });
}

/// Master output object — produced by TDEECalculator.calculateAll().
class NutritionPlan {
  final double bmr;
  final double tdee;            // After activity multiplier + body fat modifier, rounded to nearest 10
  final double tdeeLow;         // tdee − 100
  final double tdeeHigh;        // tdee + 100
  final double targetCalories;  // After pace slider, with floor clamping
  final double weeklyPacePercent;        // e.g. 0.0075 = 0.75%
  final double dailyDeficitSurplus;     // negative = deficit, positive = surplus
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;
  final double sugarG;
  final DateTime? goalEndDate;  // null if goal = maintain
  final bool carbWarning;
  final bool calorieFloorApplied;
  final double proteinMultiplier; // final g/kg multiplier used

  const NutritionPlan({
    required this.bmr,
    required this.tdee,
    required this.tdeeLow,
    required this.tdeeHigh,
    required this.targetCalories,
    required this.weeklyPacePercent,
    required this.dailyDeficitSurplus,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
    required this.sugarG,
    this.goalEndDate,
    this.carbWarning = false,
    this.calorieFloorApplied = false,
    this.proteinMultiplier = 1.8,
  });
}

// ---------------------------------------------------------------------------
// TDEECalculator — all methods are static pure functions
// ---------------------------------------------------------------------------

class TDEECalculator {
  TDEECalculator._();

  // -------------------------------------------------------------------------
  // Activity multipliers
  // -------------------------------------------------------------------------
  static const Map<String, double> _activityMultipliers = {
    'sedentary':          1.2,
    'lightly_active':     1.375,
    'moderately_active':  1.55,
    'very_active':        1.725,
  };

  // -------------------------------------------------------------------------
  // Body fat range → Protein multiplier table (g per kg bodyweight)
  // -------------------------------------------------------------------------
  static const Map<String, double> _bfProteinMultipliers = {
    '3-5':   2.4,
    '6-10':  2.3,
    '11-13': 2.2,
    '13-16': 2.1,
    '16-20': 2.0,
    '21-25': 1.9,
    '26-30': 1.8,
    '31-34': 1.7,
    '35-39': 1.6,
    '40+':   1.5,
  };

  static const double _proteinFloor   = 1.4;
  static const double _proteinCeiling = 2.7;

  // -------------------------------------------------------------------------
  // Body fat range → TDEE modifier table
  // Modifiers softened per scientific review — self-estimated BF% carries ~3-6% error margin
  // -------------------------------------------------------------------------
  static const Map<String, double> _bodyFatModifiers = {
    '3-5':   0.03,
    '6-10':  0.03,
    '11-13': 0.02,
    '13-16': 0.02,
    '16-20': 0.01,
    '21-25': 0.00,
    '26-30': -0.01,
    '31-34': -0.02,
    '35-39': -0.02,
    '40+':   -0.03,
  };

  // Minimum calorie floors (kcal/day)
  static const double _floorFemale = 1200.0;
  static const double _floorMale   = 1500.0;

  // -------------------------------------------------------------------------
  // Step 1 — BMR (Mifflin-St Jeor)
  // -------------------------------------------------------------------------
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String biologicalSex,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return biologicalSex == 'male' ? base + 5 : base - 161;
  }

  // -------------------------------------------------------------------------
  // Step 2 — TDEE (BMR × activity multiplier)
  // -------------------------------------------------------------------------
  static double calculateTDEE(double bmr, String activityLevel) {
    final multiplier = _activityMultipliers[activityLevel] ?? 1.2;
    return bmr * multiplier;
  }

  // -------------------------------------------------------------------------
  // Step 3 — Body fat modifier (optional — pass null to skip)
  // Returns TDEE rounded to nearest 10.
  // -------------------------------------------------------------------------
  static double applyBodyFatModifier(double tdee, String? bodyFatRange) {
    if (bodyFatRange == null) {
      return _roundToNearest10(tdee);
    }
    final modifier = _bodyFatModifiers[bodyFatRange] ?? 0.0;
    final adjusted = tdee * (1 + modifier);
    return _roundToNearest10(adjusted);
  }

  static double _roundToNearest10(double value) {
    return (value / 10).round() * 10.0;
  }

  // -------------------------------------------------------------------------
  // Step 4a — Weekly weight change from pace slider
  // -------------------------------------------------------------------------
  static double calculateWeeklyWeightChange({
    required double weightKg,
    required double pacePercent, // e.g. 0.75 means 0.75% of bodyweight
  }) {
    return weightKg * (pacePercent / 100);
  }

  // -------------------------------------------------------------------------
  // Step 4b — Daily calorie adjustment from weekly weight change
  // 1 kg body weight ≈ 7700 kcal
  // -------------------------------------------------------------------------
  static double calculateDailyCalorieAdjustment(double weeklyWeightChangeKg) {
    return (weeklyWeightChangeKg * 7700) / 7;
  }

  // -------------------------------------------------------------------------
  // Step 4c — Target calories with floor clamping
  // Returns a record with the clamped value and a flag.
  // -------------------------------------------------------------------------
  static ({double calories, bool floorApplied}) calculateTargetCalories({
    required double tdee,
    required double dailyCalorieAdjustment,
    required String goal,
    required String biologicalSex,
  }) {
    double target;
    switch (goal) {
      case 'lose':
        target = tdee - dailyCalorieAdjustment;
        break;
      case 'gain':
        target = tdee + dailyCalorieAdjustment;
        break;
      default:
        return (calories: tdee, floorApplied: false);
    }

    final floor = biologicalSex == 'male' ? _floorMale : _floorFemale;
    if (target < floor) {
      return (calories: floor, floorApplied: true);
    }
    return (calories: target, floorApplied: false);
  }

  // -------------------------------------------------------------------------
  // Step 4d — Goal end date
  // Returns null if: goal=maintain, no targetWeight, or diff < 1kg
  // -------------------------------------------------------------------------
  static DateTime? calculateGoalEndDate({
    required double currentWeight,
    required double? targetWeight,
    required double dailyCalorieAdjustment,
  }) {
    if (targetWeight == null) return null;
    final diff = (currentWeight - targetWeight).abs();
    if (diff < 1.0) return null;
    if (dailyCalorieAdjustment <= 0) return null;

    final totalCalories = diff * 7700;
    final daysNeeded = (totalCalories / dailyCalorieAdjustment).round();
    return DateTime.now().add(Duration(days: daysNeeded));
  }

  // -------------------------------------------------------------------------
  // Step 4e — Caution zone check
  // -------------------------------------------------------------------------
  static bool isInCautionZone(double pacePercent, String goal) {
    if (goal == 'lose') return pacePercent > 1.0;
    if (goal == 'gain') return pacePercent > 0.8;
    return false;
  }

  // -------------------------------------------------------------------------
  // Step 5 — Macros from target calories
  // Protein: dynamic multiplier from body fat range + preference + floor/ceiling.
  // Priority: protein → fat → carbs (remainder).
  // Negative carbs fallback: reduce fat to 20%, retry once.
  // -------------------------------------------------------------------------

  /// Returns the final protein multiplier (g/kg) given body fat range and preference.
  static double resolveProteinMultiplier({
    required String? bodyFatRange,
    required String proteinPreference,
  }) {
    // Step 1 — Base multiplier from BF range (default 1.8 if skipped)
    final base = _bfProteinMultipliers[bodyFatRange] ?? 1.8;

    // Step 2 — Preference adjustment
    final adjustment = switch (proteinPreference) {
      'high'        => 0.3,
      'comfortable' => -0.3,
      _             => 0.0,
    };

    // Step 3 — Clamp within safe bounds
    return (base + adjustment).clamp(_proteinFloor, _proteinCeiling);
  }

  static MacroTargets calculateMacros({
    required double targetCalories,
    required double weightKg,
    required double heightCm,
    required String biologicalSex,
    String? bodyFatRange,
    String proteinPreference = 'moderate',
  }) {
    final multiplier = resolveProteinMultiplier(
      bodyFatRange: bodyFatRange,
      proteinPreference: proteinPreference,
    );

    // Effective weight cap per scientific review — prevents impractical protein
    // targets in high-BF, high-BMI users.
    // Applies ONLY to protein gram calculation. All other macros use weightKg.
    final double heightM = heightCm / 100;
    final double bmi = weightKg / (heightM * heightM);
    final bool applyEffectiveCap =
        (bodyFatRange == '35-39' || bodyFatRange == '40+') && bmi >= 35.0;
    final double effectiveWeightKg = applyEffectiveCap ? weightKg * 0.80 : weightKg;

    final protein = effectiveWeightKg * multiplier;
    final proteinCal = protein * 4;

    double fatPercent = 0.25;
    double fatCal = targetCalories * fatPercent;
    double fat = fatCal / 9;

    double carbCal = targetCalories - proteinCal - fatCal;
    double carbs = carbCal / 4;
    bool carbWarning = false;

    // Negative carbs — reduce fat to 20% and retry
    if (carbs < 0) {
      fatPercent = 0.20;
      fatCal = targetCalories * fatPercent;
      fat = fatCal / 9;
      carbCal = targetCalories - proteinCal - fatCal;
      carbs = carbCal / 4;

      // Still negative — clamp to 0 and warn
      if (carbs < 0) {
        carbs = 0;
        carbWarning = true;
      }
    }

    final fiber = biologicalSex == 'male' ? 38.0 : 25.0;

    return MacroTargets(
      protein: protein.clamp(0, double.infinity).roundToDouble(),
      fat: fat.clamp(0, double.infinity).roundToDouble(),
      carbs: carbs.clamp(0, double.infinity).roundToDouble(),
      fiber: fiber,
      sodiumMg: 2300,
      sugarG: 50,
      carbWarning: carbWarning,
      proteinMultiplier: multiplier,
    );
  }

  // -------------------------------------------------------------------------
  // Master method — calculateAll()
  // Orchestrates every step and returns a complete NutritionPlan.
  // -------------------------------------------------------------------------
  static NutritionPlan calculateAll({
    required UserModel user,
    required double weeklyPacePercent, // slider value (e.g. 0.75 for 0.75%)
  }) {
    // Step 1 — BMR
    final bmr = calculateBMR(
      weightKg: user.weightKg,
      heightCm: user.heightCm,
      age: user.age,
      biologicalSex: user.biologicalSex,
    );

    // Step 2 — Raw TDEE
    final rawTdee = calculateTDEE(bmr, user.activityLevel);

    // Step 3 — Body fat modifier + round to nearest 10
    final tdee = applyBodyFatModifier(rawTdee, user.bodyFatRange);

    // Step 4a-c — Derive target calories from pace
    double dailyAdjustment = 0.0;
    bool floorApplied = false;
    double targetCalories = tdee;

    if (user.goal != 'maintain') {
      final weeklyChange = calculateWeeklyWeightChange(
        weightKg: user.weightKg,
        pacePercent: weeklyPacePercent,
      );
      dailyAdjustment = calculateDailyCalorieAdjustment(weeklyChange);

      final result = calculateTargetCalories(
        tdee: tdee,
        dailyCalorieAdjustment: dailyAdjustment,
        goal: user.goal,
        biologicalSex: user.biologicalSex,
      );
      targetCalories = result.calories;
      floorApplied = result.floorApplied;
    }

    // Deficit is negative for loss, positive for gain
    final dailyDeficitSurplus = user.goal == 'lose'
        ? -dailyAdjustment
        : user.goal == 'gain'
            ? dailyAdjustment
            : 0.0;

    // Step 5 — Macros (dynamic protein: BF range + preference + effective weight cap if applicable)
    final macros = calculateMacros(
      targetCalories: targetCalories,
      weightKg: user.weightKg,
      heightCm: user.heightCm,
      biologicalSex: user.biologicalSex,
      bodyFatRange: user.bodyFatRange,
      proteinPreference: user.proteinPreference,
    );

    // Step 4d — Goal end date (only for lose/gain with target weight)
    DateTime? goalEndDate;
    if (user.goal != 'maintain' && dailyAdjustment > 0) {
      goalEndDate = calculateGoalEndDate(
        currentWeight: user.weightKg,
        targetWeight: user.targetWeightKg,
        dailyCalorieAdjustment: dailyAdjustment,
      );
    }

    return NutritionPlan(
      bmr: bmr,
      tdee: tdee,
      tdeeLow: tdee - 100,
      tdeeHigh: tdee + 100,
      targetCalories: targetCalories,
      weeklyPacePercent: weeklyPacePercent,
      dailyDeficitSurplus: dailyDeficitSurplus,
      proteinG: macros.protein,
      carbsG: macros.carbs,
      fatG: macros.fat,
      fiberG: macros.fiber,
      sodiumMg: macros.sodiumMg,
      sugarG: macros.sugarG,
      goalEndDate: goalEndDate,
      carbWarning: macros.carbWarning,
      calorieFloorApplied: floorApplied,
      proteinMultiplier: macros.proteinMultiplier,
    );
  }
}
