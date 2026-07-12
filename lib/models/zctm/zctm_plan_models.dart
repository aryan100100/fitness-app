// [ZCTM] — Meal Plan Models (Zero-Calorie-Tracking Mode)
// Protein-first meal plan. No calorie numbers shown to user.
// Separate from MealPlanResult (calorie-tracking mode) to avoid confusion.

/// Input sent to Gemini for a ZCTM daily meal plan.
class ZCTMPlanInput {
  final double proteinTargetG;
  final String lifeSituation;        // hostel | office | wfh | student | other
  final String region;               // India | USA | UK | Other
  final String biologicalSex;        // male | female (for fibre target)
  final List<String> foodPreferences; // vegetarian, dairy-free, etc.
  final List<String> recentMealNames; // last 7 days — variety rule

  const ZCTMPlanInput({
    required this.proteinTargetG,
    required this.lifeSituation,
    required this.region,
    required this.biologicalSex,
    required this.foodPreferences,
    required this.recentMealNames,
  });

  Map<String, dynamic> toJson() => {
        'protein_target_g': proteinTargetG,
        'life_situation': lifeSituation,
        'region': region,
        'biological_sex': biologicalSex,
        'food_preferences': foodPreferences,
        'recent_meal_names': recentMealNames,
      };
}

/// A single food item within a ZCTM meal.
class ZCTMMealItem {
  final String name;
  final String quantity;    // human-readable, e.g. "1 cup (240ml)"
  final double proteinG;
  final double fiberG;

  const ZCTMMealItem({
    required this.name,
    required this.quantity,
    required this.proteinG,
    required this.fiberG,
  });

  factory ZCTMMealItem.fromJson(Map<String, dynamic> j) => ZCTMMealItem(
        name: j['name'] as String? ?? '',
        quantity: j['quantity'] as String? ?? '',
        proteinG: (j['protein_g'] as num?)?.toDouble() ?? 0,
        fiberG: (j['fiber_g'] as num?)?.toDouble() ?? 0,
      );
}

/// A single meal (breakfast / lunch / dinner / snack) in the ZCTM plan.
class ZCTMPlannedMeal {
  final String mealType;     // breakfast | lunch | dinner | snack
  final String mealName;
  final List<ZCTMMealItem> items;
  final double totalProteinG;
  final double totalFiberG;
  final String prepNote;     // MUST NOT mention calories or kcal

  const ZCTMPlannedMeal({
    required this.mealType,
    required this.mealName,
    required this.items,
    required this.totalProteinG,
    required this.totalFiberG,
    required this.prepNote,
  });

  factory ZCTMPlannedMeal.fromJson(Map<String, dynamic> j) => ZCTMPlannedMeal(
        mealType: j['meal_type'] as String? ?? '',
        mealName: j['meal_name'] as String? ?? '',
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => ZCTMMealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalProteinG: (j['total_protein_g'] as num?)?.toDouble() ?? 0,
        totalFiberG: (j['total_fiber_g'] as num?)?.toDouble() ?? 0,
        prepNote: j['prep_note'] as String? ?? '',
      );
}

/// The full ZCTM day plan returned by Gemini.
class ZCTMMealPlan {
  final String planDate;
  final double totalProteinG;
  final double totalFiberG;
  final List<ZCTMPlannedMeal> meals;

  const ZCTMMealPlan({
    required this.planDate,
    required this.totalProteinG,
    required this.totalFiberG,
    required this.meals,
  });

  factory ZCTMMealPlan.fromJson(Map<String, dynamic> j) => ZCTMMealPlan(
        planDate: j['plan_date'] as String? ?? '',
        totalProteinG: (j['total_protein_g'] as num?)?.toDouble() ?? 0,
        totalFiberG: (j['total_fiber_g'] as num?)?.toDouble() ?? 0,
        meals: (j['meals'] as List<dynamic>? ?? [])
            .map((e) => ZCTMPlannedMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
