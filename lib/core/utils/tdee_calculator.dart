// [HEALTH APP] — TDEE & Macro Calculator Engine
// Pure Dart — no Flutter imports. Reusable from any screen or service.
// Formula: Mifflin-St Jeor BMR + activity multiplier

class MacroTargets {
  final double protein; // grams
  final double fat;     // grams
  final double carbs;   // grams
  final double fiber;   // grams

  const MacroTargets({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
  });

  @override
  String toString() =>
      'Protein: ${protein.toStringAsFixed(1)}g | '
      'Fat: ${fat.toStringAsFixed(1)}g | '
      'Carbs: ${carbs.toStringAsFixed(1)}g | '
      'Fiber: ${fiber.toStringAsFixed(1)}g';
}

class TdeeResult {
  final double bmr;
  final double tdee;           // maintenance calories
  final double targetCalories; // goal-adjusted calories
  final MacroTargets macros;

  const TdeeResult({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.macros,
  });
}

class TdeeCalculator {
  TdeeCalculator._();

  // Activity level multipliers
  static const Map<String, double> _activityMultipliers = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
    'very_active': 1.725,
  };

  // Calorie adjustments by goal
  static const Map<String, double> _goalAdjustments = {
    'lose': -400.0,
    'gain': 300.0,
    'maintain': 0.0,
  };

  /// Calculates BMR using the Mifflin-St Jeor formula.
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required String biologicalSex, // 'male' or 'female'
  }) {
    // Male:   (10 × weight) + (6.25 × height) − (5 × age) + 5
    // Female: (10 × weight) + (6.25 × height) − (5 × age) − 161
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return biologicalSex == 'male' ? base + 5 : base - 161;
  }

  /// Full TDEE + target calories + macro calculation.
  static TdeeResult calculate({
    required double weightKg,
    required double heightCm,
    required int age,
    required String biologicalSex,  // 'male' | 'female'
    required String activityLevel,  // 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active'
    required String goal,           // 'lose' | 'gain' | 'maintain'
  }) {
    final bmr = calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      biologicalSex: biologicalSex,
    );

    final multiplier = _activityMultipliers[activityLevel] ?? 1.2;
    final tdee = bmr * multiplier;

    final adjustment = _goalAdjustments[goal] ?? 0.0;
    final targetCalories = tdee + adjustment;

    final macros = _calculateMacros(
      targetCalories: targetCalories,
      weightKg: weightKg,
      biologicalSex: biologicalSex,
    );

    return TdeeResult(
      bmr: bmr,
      tdee: tdee,
      targetCalories: targetCalories,
      macros: macros,
    );
  }

  /// Macro split:
  ///   Protein: 1.8g × bodyweight (calculated first)
  ///   Fat:     25% of target calories (÷ 9 for grams)
  ///   Carbs:   remaining calories (÷ 4 for grams)
  ///   Fiber:   38g male / 25g female
  static MacroTargets _calculateMacros({
    required double targetCalories,
    required double weightKg,
    required String biologicalSex,
  }) {
    final protein = weightKg * 1.8;
    final proteinCalories = protein * 4;

    final fat = (targetCalories * 0.25) / 9;
    final fatCalories = fat * 9;

    final remainingCalories = targetCalories - proteinCalories - fatCalories;
    final carbs = remainingCalories / 4;

    final fiber = biologicalSex == 'male' ? 38.0 : 25.0;

    return MacroTargets(
      protein: protein.clamp(0, double.infinity),
      fat: fat.clamp(0, double.infinity),
      carbs: carbs.clamp(0, double.infinity),
      fiber: fiber,
    );
  }
}
