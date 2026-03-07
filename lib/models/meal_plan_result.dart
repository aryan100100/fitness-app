// [HEALTH APP] — Meal Plan Result Models
// Data structures that mirror the Gemini meal plan JSON response.

class MealItem {
  final String name;
  final String quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  const MealItem({
    required this.name,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
  });

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
        name:     j['name']     as String? ?? '',
        quantity: j['quantity'] as String? ?? '',
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        protein:  (j['protein']  as num?)?.toDouble() ?? 0,
        carbs:    (j['carbs']    as num?)?.toDouble() ?? 0,
        fat:      (j['fat']      as num?)?.toDouble() ?? 0,
        fibre:    (j['fibre']    as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
      };
}

class PlannedMeal {
  final String mealType;  // breakfast | lunch | dinner | snack
  final String mealName;
  final List<MealItem> items;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFibre;
  final String prepNote;
  bool isLogged; // runtime state only — not persisted

  PlannedMeal({
    required this.mealType,
    required this.mealName,
    required this.items,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFibre,
    required this.prepNote,
    this.isLogged = false,
  });

  factory PlannedMeal.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final items = rawItems is List
        ? rawItems.map((e) => MealItem.fromJson(e as Map<String, dynamic>)).toList()
        : <MealItem>[];
    return PlannedMeal(
      mealType:      j['mealType']      as String? ?? '',
      mealName:      j['mealName']      as String? ?? '',
      items:         items,
      totalCalories: (j['totalCalories'] as num?)?.toDouble() ?? 0,
      totalProtein:  (j['totalProtein']  as num?)?.toDouble() ?? 0,
      totalCarbs:    (j['totalCarbs']    as num?)?.toDouble() ?? 0,
      totalFat:      (j['totalFat']      as num?)?.toDouble() ?? 0,
      totalFibre:    (j['totalFibre']    as num?)?.toDouble() ?? 0,
      prepNote:      j['prepNote']       as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'mealType': mealType,
        'mealName': mealName,
        'items': items.map((e) => e.toJson()).toList(),
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFat': totalFat,
        'totalFibre': totalFibre,
        'prepNote': prepNote,
      };

  String get mealIcon {
    switch (mealType) {
      case 'breakfast': return '🌅';
      case 'lunch':     return '☀️';
      case 'dinner':    return '🌙';
      case 'snack':     return '🍎';
      default:          return '🍽️';
    }
  }
}

class MealPlanResult {
  final String planDate;   // yyyy-MM-dd
  final List<PlannedMeal> meals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFibre;

  const MealPlanResult({
    required this.planDate,
    required this.meals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFibre,
  });

  factory MealPlanResult.fromJson(Map<String, dynamic> j) {
    final rawMeals = j['meals'];
    final meals = rawMeals is List
        ? rawMeals.map((e) => PlannedMeal.fromJson(e as Map<String, dynamic>)).toList()
        : <PlannedMeal>[];
    return MealPlanResult(
      planDate:      j['planDate']      as String? ?? '',
      meals:         meals,
      totalCalories: (j['totalCalories'] as num?)?.toDouble() ?? 0,
      totalProtein:  (j['totalProtein']  as num?)?.toDouble() ?? 0,
      totalCarbs:    (j['totalCarbs']    as num?)?.toDouble() ?? 0,
      totalFat:      (j['totalFat']      as num?)?.toDouble() ?? 0,
      totalFibre:    (j['totalFibre']    as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'planDate': planDate,
        'meals': meals.map((e) => e.toJson()).toList(),
        'totalCalories': totalCalories,
        'totalProtein': totalProtein,
        'totalCarbs': totalCarbs,
        'totalFat': totalFat,
        'totalFibre': totalFibre,
      };
}
