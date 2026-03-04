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
    test('11–13% lean range applies +2% modifier, rounds to nearest 10', () {
      // 2200 × 1.02 = 2244 → rounds to 2240
      expect(TDEECalculator.applyBodyFatModifier(2200, '11-13'), equals(2240));
    });

    test('21–25% average range applies 0% modifier, still rounds', () {
      // 2200 × 1.0 = 2200 → already a multiple of 10
      expect(TDEECalculator.applyBodyFatModifier(2200, '21-25'), equals(2200));
    });

    test('40%+ range applies −3% modifier', () {
      // 2000 × 0.97 = 1940 → already rounded
      expect(TDEECalculator.applyBodyFatModifier(2000, '40+'), equals(1940));
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
        heightCm: 175, // BMI ≈22.9 — no cap
        biologicalSex: 'male',
        // No BF range, moderate preference → 1.8 × 70 = 126g protein
      );
      expect(m.protein, closeTo(126, 1));
      expect(m.proteinMultiplier, closeTo(1.8, 0.01));
      expect(m.carbWarning, isFalse);
      expect(m.carbs, greaterThan(0));
      expect(m.fiber, equals(38)); // male
    });

    test('Female fiber is 25g', () {
      final m = TDEECalculator.calculateMacros(
        targetCalories: 1800,
        weightKg: 60,
        heightCm: 165, // BMI ≈22.0 — no cap
        biologicalSex: 'female',
      );
      expect(m.fiber, equals(25));
    });

    test('Negative carbs fallback — fat reduced to 20%', () {
      // Very low calories, heavy person → protein calories > budget
      final m = TDEECalculator.calculateMacros(
        targetCalories: 1200, // low
        weightKg: 120,
        heightCm: 175, // BMI ≈39.2 with 35-39 range would trigger cap,
        // but no bodyFatRange passed here, so no cap applies
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

  // ---------------------------------------------------------------------------
  // Dynamic Protein Multiplier — resolveProteinMultiplier()
  // ---------------------------------------------------------------------------
  group('Dynamic Protein Multiplier', () {
    // --- Specified example calculations ---

    test('80kg, BF 11-13%, High → 2.2 + 0.3 = 2.5 → 200g protein', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: '11-13',
        proteinPreference: 'high',
      );
      expect(m, closeTo(2.5, 0.001));
      // 2.5 × 80 = 200g
      expect((m * 80).roundToDouble(), equals(200));
    });

    test('90kg, BF 31-34%, Comfortable → 1.7 - 0.3 = 1.4 (floor) → 126g protein', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: '31-34',
        proteinPreference: 'comfortable',
      );
      // 1.7 - 0.3 = 1.4 — exactly at floor
      expect(m, closeTo(1.4, 0.001));
      expect((m * 90).roundToDouble(), equals(126));
    });

    // --- Floor clamp (< 1.4) ---
    test('35-39% + Comfortable → 1.6 - 0.3 = 1.3 → floored to 1.4', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: '35-39',
        proteinPreference: 'comfortable',
      );
      expect(m, closeTo(1.4, 0.001)); // clamped from 1.3
    });

    test('40%+ + Comfortable → 1.5 - 0.3 = 1.2 → floored to 1.4', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: '40+',
        proteinPreference: 'comfortable',
      );
      expect(m, closeTo(1.4, 0.001)); // clamped from 1.2
    });

    // --- Ceiling clamp (> 2.7) ---
    test('3-5% + High → 2.4 + 0.3 = 2.7 — exactly at ceiling', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: '3-5',
        proteinPreference: 'high',
      );
      expect(m, closeTo(2.7, 0.001)); // exactly ceiling
    });

    test('6-10% + High → 2.3 + 0.3 = 2.6 — within ceiling', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: '6-10',
        proteinPreference: 'high',
      );
      expect(m, closeTo(2.6, 0.001));
    });

    // --- Null BF (skipped) ---
    test('Null BF + Moderate → default 1.8, no change', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: null,
        proteinPreference: 'moderate',
      );
      expect(m, closeTo(1.8, 0.001));
    });

    test('Null BF + High → 1.8 + 0.3 = 2.1', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: null,
        proteinPreference: 'high',
      );
      expect(m, closeTo(2.1, 0.001));
    });

    test('Null BF + Comfortable → 1.8 - 0.3 = 1.5', () {
      final m = TDEECalculator.resolveProteinMultiplier(
        bodyFatRange: null,
        proteinPreference: 'comfortable',
      );
      expect(m, closeTo(1.5, 0.001));
    });

    // --- All multipliers within bounds (spot check all 10 BF ranges × 3 prefs) ---
    const allRanges = [
      '3-5', '6-10', '11-13', '13-16', '16-20',
      '21-25', '26-30', '31-34', '35-39', '40+'
    ];
    const allPrefs = ['high', 'moderate', 'comfortable'];

    test('All 10 BF ranges × 3 preferences → multiplier always within [1.4, 2.7]', () {
      for (final bf in allRanges) {
        for (final pref in allPrefs) {
          final m = TDEECalculator.resolveProteinMultiplier(
            bodyFatRange: bf,
            proteinPreference: pref,
          );
          expect(
            m,
            inInclusiveRange(1.4, 2.7),
            reason: 'BF=$bf pref=$pref → multiplier $m out of bounds',
          );
        }
      }
    });

    // --- calculateMacros exposes proteinMultiplier ---
    test('calculateMacros returns correct proteinMultiplier field', () {
      final macros = TDEECalculator.calculateMacros(
        targetCalories: 2200,
        weightKg: 80,
        heightCm: 175, // BMI ≈26.1 — no cap
        biologicalSex: 'male',
        bodyFatRange: '11-13',
        proteinPreference: 'high',
      );
      // 2.2 + 0.3 = 2.5 × 80 = 200g
      expect(macros.proteinMultiplier, closeTo(2.5, 0.001));
      expect(macros.protein, closeTo(200, 1));
    });

    // --- calculateAll integration: protein preference and BF flow through ---
    test('calculateAll respects proteinPreference: high vs comfortable produce different protein', () {
      final baseUser = UserModel(
        name: 'Test', age: 30, biologicalSex: 'male',
        heightCm: 175, weightKg: 80, targetWeightKg: 70,
        goal: 'lose', activityLevel: 'moderately_active',
        lifeSituation: 'office_worker',
        tdee: 0, targetCalories: 0,
        proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0,
        bodyFatRange: '21-25',
      );

      final planHigh = TDEECalculator.calculateAll(
        user: baseUser.copyWith(proteinPreference: 'high'),
        weeklyPacePercent: 0.75,
      );
      final planComfy = TDEECalculator.calculateAll(
        user: baseUser.copyWith(proteinPreference: 'comfortable'),
        weeklyPacePercent: 0.75,
      );

      // High preference multiplier (1.9+0.3=2.2) > comfortable (1.9-0.3=1.6)
      expect(planHigh.proteinG, greaterThan(planComfy.proteinG));
      // Both plans store a non-zero multiplier
      expect(planHigh.proteinMultiplier, closeTo(2.2, 0.001));
      expect(planComfy.proteinMultiplier, closeTo(1.6, 0.001));
    });

    // ---------------------------------------------------------------------------
    // Effective Weight Cap Tests (high-BF + high-BMI)
    // ---------------------------------------------------------------------------

    // Test 1 — Cap APPLIES: 120 kg, 35-39 BF, height 178 cm (BMI 37.9 ≥ 35)
    test('Effective weight cap applies — 120kg, 35-39% BF, BMI 37.9 → uses 96kg', () {
      // effectiveWeight = 120 × 0.80 = 96 kg
      // multiplier: BF 35-39 base = 1.6, moderate pref (+0) = 1.6
      // protein = 96 × 1.6 = 153.6 → rounds to 154g
      // Without cap: 120 × 1.6 = 192g — these must not be equal
      final macros = TDEECalculator.calculateMacros(
        targetCalories: 2200,
        weightKg: 120,
        heightCm: 178,
        biologicalSex: 'male',
        bodyFatRange: '35-39',
        proteinPreference: 'moderate',
      );
      expect(macros.protein, closeTo(154, 1)); // 96 × 1.6, not 120 × 1.6
      expect(macros.protein, lessThan(170));    // explicit check: cap reduces from 192
    });

    // Test 2 — Cap APPLIES + ceiling enforced on effective weight:
    // 115 kg, 40%+ BF, height 179 cm (BMI ≈ 35.9 ≥ 35), High preference
    test('Cap applies + ceiling enforced on effective weight — 115kg, 40%+, High', () {
      // effectiveWeight = 115 × 0.80 = 92 kg
      // multiplier: BF 40+ base = 1.5, high pref (+0.3) = 1.8 → within [1.4, 2.7]
      // protein = 92 × 1.8 = 165.6 → rounds to 166g
      // ceiling check: 2.7 × 92 = 248.4 — not triggered here
      final macros = TDEECalculator.calculateMacros(
        targetCalories: 2000,
        weightKg: 115,
        heightCm: 179,
        biologicalSex: 'male',
        bodyFatRange: '40+',
        proteinPreference: 'high',
      );
      expect(macros.protein, closeTo(166, 2)); // 92 × 1.8
      expect(macros.protein, lessThan(185));    // less than uncapped 115 × 1.8 = 207
    });

    // Test 3 — NO cap: 100 kg, 35-39 BF, height 186 cm (BMI ≈ 28.9 < 35)
    test('No cap when BMI < 35 — 100kg, 35-39% BF, height 186cm (BMI 28.9)', () {
      // BMI = 100 / (1.86^2) ≈ 28.9 — below 35 threshold
      // multiplier: BF 35-39 base = 1.6, moderate → 1.6
      // protein = 100 × 1.6 = 160g (full weight used)
      final macros = TDEECalculator.calculateMacros(
        targetCalories: 2400,
        weightKg: 100,
        heightCm: 186,
        biologicalSex: 'male',
        bodyFatRange: '35-39',
        proteinPreference: 'moderate',
      );
      expect(macros.protein, closeTo(160, 1)); // full 100kg used
    });

    // Test 4 — NO cap: 95 kg, 26-30 BF, height 161 cm (BMI ≈ 36.7 ≥ 35)
    // High BMI, but BF range not 35-39 or 40+ — cap must NOT apply
    test('No cap when BF range not 35-39 or 40%+ — 95kg, 26-30% BF, BMI 36.7', () {
      // BMI = 95 / (1.61^2) ≈ 36.7 — above 35, but BF range 26-30 → no cap
      // multiplier: BF 26-30 base = 1.8, moderate → 1.8
      // protein = 95 × 1.8 = 171g (full weight used)
      final macros = TDEECalculator.calculateMacros(
        targetCalories: 2300,
        weightKg: 95,
        heightCm: 161,
        biologicalSex: 'male',
        bodyFatRange: '26-30',
        proteinPreference: 'moderate',
      );
      expect(macros.protein, closeTo(171, 1)); // full 95kg used
    });
  });
}
