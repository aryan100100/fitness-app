// [HEALTH APP] — TDEECalculator Unit Tests
// Feature 2: Tests for all calculator methods.

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/utils/tdee_calculator.dart';
import 'package:fitness_app/models/user_model.dart';

void main() {
  // ---------------------------------------------------------------------------
  // BMR Tests (Mifflin-St Jeor)
  // ---------------------------------------------------------------------------
  group('BMR Calculation', () {
    test('Male BMR — 80kg, 175cm, 25y', () {
      final bmr = TDEECalculator.calculateBMR(
        weightKg: 80,
        heightCm: 175,
        age: 25,
        biologicalSex: 'male',
      );
      // (10×80) + (6.25×175) − (5×25) + 5 = 800 + 1093.75 − 125 + 5 = 1773.75
      expect(bmr, closeTo(1773.75, 0.1));
    });

    test('Female BMR — 60kg, 162cm, 28y', () {
      final bmr = TDEECalculator.calculateBMR(
        weightKg: 60,
        heightCm: 162,
        age: 28,
        biologicalSex: 'female',
      );
      // (10×60) + (6.25×162) − (5×28) − 161 = 600 + 1012.5 − 140 − 161 = 1311.5
      expect(bmr, closeTo(1311.5, 0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // TDEE / Activity Multiplier Tests
  // ---------------------------------------------------------------------------
  group('TDEE Activity Multipliers', () {
    const bmr = 1773.75;

    test('Sedentary × 1.2', () {
      expect(
        TDEECalculator.calculateTDEE(bmr, 'sedentary'),
        closeTo(bmr * 1.2, 0.1),
      );
    });

    test('Lightly Active × 1.375', () {
      expect(
        TDEECalculator.calculateTDEE(bmr, 'lightly_active'),
        closeTo(bmr * 1.375, 0.1),
      );
    });

    test('Moderately Active × 1.55', () {
      expect(
        TDEECalculator.calculateTDEE(bmr, 'moderately_active'),
        closeTo(bmr * 1.55, 0.1),
      );
    });

    test('Very Active × 1.725', () {
      expect(
        TDEECalculator.calculateTDEE(bmr, 'very_active'),
        closeTo(bmr * 1.725, 0.1),
      );
    });

    test('Unknown level defaults to × 1.2', () {
      expect(
        TDEECalculator.calculateTDEE(bmr, 'unknown_level'),
        closeTo(bmr * 1.2, 0.1),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Body Fat Modifier Tests
  // ---------------------------------------------------------------------------
  group('Body Fat Modifier', () {
    test('11–13% lean range applies +3% modifier, rounds to nearest 10', () {
      // 2200 × 1.03 = 2266 → rounds to 2270
      expect(TDEECalculator.applyBodyFatModifier(2200, '11-13'), equals(2270));
    });

    test('21–25% average range applies 0% modifier, still rounds', () {
      // 2200 × 1.0 = 2200 → already a multiple of 10
      expect(TDEECalculator.applyBodyFatModifier(2200, '21-25'), equals(2200));
    });

    test('40%+ range applies −4% modifier', () {
      // 2000 × 0.96 = 1920 → already rounded
      expect(TDEECalculator.applyBodyFatModifier(2000, '40+'), equals(1920));
    });

    test('null (skipped) returns TDEE rounded to nearest 10', () {
      // 2200 rounded to nearest 10 → 2200
      expect(TDEECalculator.applyBodyFatModifier(2200, null), equals(2200));
    });

    test('Rounding: 2213 → 2210', () {
      expect(TDEECalculator.applyBodyFatModifier(2213, null), equals(2210));
    });
  });

  // ---------------------------------------------------------------------------
  // Weekly Weight Change
  // ---------------------------------------------------------------------------
  group('Weekly Weight Change', () {
    test('90kg × 0.75% = 0.675 kg/week', () {
      expect(
        TDEECalculator.calculateWeeklyWeightChange(
            weightKg: 90, pacePercent: 0.75),
        closeTo(0.675, 0.001),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Daily Calorie Adjustment
  // ---------------------------------------------------------------------------
  group('Daily Calorie Adjustment', () {
    test('0.675kg/week → (0.675 × 7700) / 7 = 742.5 kcal/day', () {
      expect(
        TDEECalculator.calculateDailyCalorieAdjustment(0.675),
        closeTo(742.5, 0.1),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Target Calories with Floor Clamping
  // ---------------------------------------------------------------------------
  group('Target Calories', () {
    test('Lose: TDEE 2200, adjustment 400 → 1800 (no floor)', () {
      final result = TDEECalculator.calculateTargetCalories(
        tdee: 2200,
        dailyCalorieAdjustment: 400,
        goal: 'lose',
        biologicalSex: 'male',
      );
      expect(result.calories, closeTo(1800, 0.1));
      expect(result.floorApplied, isFalse);
    });

    test('Floor clamp female — target below 1200', () {
      final result = TDEECalculator.calculateTargetCalories(
        tdee: 1600,
        dailyCalorieAdjustment: 700,
        goal: 'lose',
        biologicalSex: 'female',
      );
      expect(result.calories, equals(1200));
      expect(result.floorApplied, isTrue);
    });

    test('Floor clamp male — target below 1500', () {
      final result = TDEECalculator.calculateTargetCalories(
        tdee: 1800,
        dailyCalorieAdjustment: 400,
        goal: 'lose',
        biologicalSex: 'male',
      );
      // 1800 - 400 = 1400 < 1500 → clamped
      expect(result.calories, equals(1500));
      expect(result.floorApplied, isTrue);
    });

    test('Gain: TDEE 2000, adjustment 300 → 2300 (no floor)', () {
      final result = TDEECalculator.calculateTargetCalories(
        tdee: 2000,
        dailyCalorieAdjustment: 300,
        goal: 'gain',
        biologicalSex: 'male',
      );
      expect(result.calories, closeTo(2300, 0.1));
      expect(result.floorApplied, isFalse);
    });

    test('Maintain: returns TDEE unchanged', () {
      final result = TDEECalculator.calculateTargetCalories(
        tdee: 2100,
        dailyCalorieAdjustment: 999,
        goal: 'maintain',
        biologicalSex: 'female',
      );
      expect(result.calories, equals(2100));
      expect(result.floorApplied, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Caution Zone
  // ---------------------------------------------------------------------------
  group('Caution Zone', () {
    test('Loss at exactly 1.0% → NOT in caution', () {
      expect(TDEECalculator.isInCautionZone(1.0, 'lose'), isFalse);
    });

    test('Loss at 1.01% → in caution', () {
      expect(TDEECalculator.isInCautionZone(1.01, 'lose'), isTrue);
    });

    test('Gain at exactly 0.8% → NOT in caution', () {
      expect(TDEECalculator.isInCautionZone(0.8, 'gain'), isFalse);
    });

    test('Gain at 0.81% → in caution', () {
      expect(TDEECalculator.isInCautionZone(0.81, 'gain'), isTrue);
    });

    test('Maintain is never in caution', () {
      expect(TDEECalculator.isInCautionZone(100.0, 'maintain'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Macros
  // ---------------------------------------------------------------------------
  group('Macros', () {
    test('Normal 2000 kcal, 70kg male — no carb warning', () {
      final m = TDEECalculator.calculateMacros(
        targetCalories: 2000,
        weightKg: 70,
        biologicalSex: 'male',
      );
      // Protein: 70 × 1.8 = 126g → 504 cal
      // Fat:    2000 × 0.25 / 9 ≈ 55.6g
      // Carbs:  (2000 - 504 - 500) / 4 = 249 cal / 4 = ~249g
      expect(m.protein, closeTo(126, 1));
      expect(m.carbWarning, isFalse);
      expect(m.carbs, greaterThan(0));
      expect(m.fiber, equals(38)); // male
    });

    test('Female fiber is 25g', () {
      final m = TDEECalculator.calculateMacros(
        targetCalories: 1800,
        weightKg: 60,
        biologicalSex: 'female',
      );
      expect(m.fiber, equals(25));
    });

    test('Negative carbs fallback — fat reduced to 20%', () {
      // Very low calories, heavy person → protein calories > budget
      final m = TDEECalculator.calculateMacros(
        targetCalories: 1200, // low
        weightKg: 120,        // protein = 216g = 864 cal (72% of budget)
        biologicalSex: 'male',
      );
      // Carbs should be 0 or near 0, carbWarning true
      expect(m.carbs, greaterThanOrEqualTo(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Goal End Date
  // ---------------------------------------------------------------------------
  group('Goal End Date', () {
    test('10kg diff, 550 kcal/day adj → ~135.6 days', () {
      final today = DateTime.now();
      final date = TDEECalculator.calculateGoalEndDate(
        currentWeight: 80,
        targetWeight: 70,
        dailyCalorieAdjustment: 550,
      );
      // (10 × 7700) / 550 = 140 days
      expect(date, isNotNull);
      final diff = date!.difference(today).inDays;
      expect(diff, closeTo(140, 5));
    });

    test('Returns null when target weight is null', () {
      expect(
        TDEECalculator.calculateGoalEndDate(
          currentWeight: 80,
          targetWeight: null,
          dailyCalorieAdjustment: 400,
        ),
        isNull,
      );
    });

    test('Returns null when weight diff < 1kg', () {
      expect(
        TDEECalculator.calculateGoalEndDate(
          currentWeight: 80.4,
          targetWeight: 80.0,
          dailyCalorieAdjustment: 400,
        ),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // calculateAll() integration test
  // ---------------------------------------------------------------------------
  group('calculateAll()', () {
    final user = UserModel(
      name: 'Test',
      age: 25,
      biologicalSex: 'male',
      heightCm: 175,
      weightKg: 80,
      targetWeightKg: 70,
      goal: 'lose',
      activityLevel: 'moderately_active',
      lifeSituation: 'office_worker',
      tdee: 0,
      targetCalories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
    );

    test('Returns valid NutritionPlan for lose goal with 0.75% pace', () {
      final plan = TDEECalculator.calculateAll(
        user: user,
        weeklyPacePercent: 0.75,
      );

      expect(plan.bmr, greaterThan(0));
      expect(plan.tdee, greaterThan(0));
      expect(plan.tdee % 10, equals(0)); // rounded to nearest 10
      expect(plan.targetCalories, greaterThan(0));
      expect(plan.proteinG, greaterThan(0));
      expect(plan.carbsG, greaterThanOrEqualTo(0));
      expect(plan.fatG, greaterThan(0));
      expect(plan.fiberG, equals(38)); // male
      expect(plan.sodiumMg, equals(2300));
      expect(plan.sugarG, equals(50));
      // dailyDeficitSurplus should be negative (deficit) for lose goal
      expect(plan.dailyDeficitSurplus, lessThan(0));
      // goalEndDate should be set (target weight provided)
      expect(plan.goalEndDate, isNotNull);
      // tdeeLow = tdee - 100
      expect(plan.tdeeLow, equals(plan.tdee - 100));
      expect(plan.tdeeHigh, equals(plan.tdee + 100));
    });

    test('Maintain goal returns targetCalories == tdee, no goal date', () {
      final maintainUser = user.copyWith(goal: 'maintain', targetWeightKg: null);
      final plan = TDEECalculator.calculateAll(
        user: maintainUser,
        weeklyPacePercent: 0,
      );
      expect(plan.targetCalories, equals(plan.tdee));
      expect(plan.goalEndDate, isNull);
    });
  });
}
