// [HEALTH APP] — Recipe Result Models
// Data structures that mirror the Gemini recipe JSON response.

class RecipeIngredient {
  final String name;
  final String quantity;
  final double gramsEquivalent;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.gramsEquivalent,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        name:             j['name']             as String? ?? '',
        quantity:         j['quantity']         as String? ?? '',
        gramsEquivalent: (j['gramsEquivalent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'gramsEquivalent': gramsEquivalent,
      };

  /// Returns a scaled quantity string for [servingMultiplier].
  /// Attempts numeric scaling; falls back to original string.
  String scaledQuantity(double servingMultiplier) {
    // Try to extract leading number from quantity string
    final match = RegExp(r'^([\d.]+)(.*)').firstMatch(quantity.trim());
    if (match != null) {
      final num = double.tryParse(match.group(1)!);
      if (num != null) {
        final scaled = num * servingMultiplier;
        final display = scaled == scaled.roundToDouble()
            ? scaled.toInt().toString()
            : scaled.toStringAsFixed(1);
        return '$display${match.group(2)}';
      }
    }
    return quantity;
  }
}

class NutritionPerServing {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;

  const NutritionPerServing({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
  });

  factory NutritionPerServing.fromJson(Map<String, dynamic> j) =>
      NutritionPerServing(
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        protein:  (j['protein']  as num?)?.toDouble() ?? 0,
        carbs:    (j['carbs']    as num?)?.toDouble() ?? 0,
        fat:      (j['fat']      as num?)?.toDouble() ?? 0,
        fibre:    (j['fibre']    as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
      };

  NutritionPerServing operator *(double factor) => NutritionPerServing(
        calories: calories * factor,
        protein:  protein  * factor,
        carbs:    carbs    * factor,
        fat:      fat      * factor,
        fibre:    fibre    * factor,
      );
}

class RecipeResult {
  final String recipeName;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final NutritionPerServing nutritionPerServing;
  final String macroNote;

  const RecipeResult({
    required this.recipeName,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.ingredients,
    required this.instructions,
    required this.nutritionPerServing,
    required this.macroNote,
  });

  factory RecipeResult.fromJson(Map<String, dynamic> j) {
    final rawIngredients = j['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList()
        : <RecipeIngredient>[];

    final rawInstructions = j['instructions'];
    final instructions = rawInstructions is List
        ? rawInstructions.map((e) => e.toString()).toList()
        : <String>[];

    final rawNutrition = j['nutritionPerServing'];
    final nutrition = rawNutrition is Map<String, dynamic>
        ? NutritionPerServing.fromJson(rawNutrition)
        : const NutritionPerServing(
            calories: 0, protein: 0, carbs: 0, fat: 0, fibre: 0);

    return RecipeResult(
      recipeName:       j['recipeName']       as String? ?? '',
      servings:         (j['servings']         as num?)?.toInt()  ?? 1,
      prepTimeMinutes:  (j['prepTimeMinutes']  as num?)?.toInt()  ?? 0,
      cookTimeMinutes:  (j['cookTimeMinutes']  as num?)?.toInt()  ?? 0,
      ingredients:      ingredients,
      instructions:     instructions,
      nutritionPerServing: nutrition,
      macroNote:        j['macroNote']         as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'recipeName': recipeName,
        'servings': servings,
        'prepTimeMinutes': prepTimeMinutes,
        'cookTimeMinutes': cookTimeMinutes,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'instructions': instructions,
        'nutritionPerServing': nutritionPerServing.toJson(),
        'macroNote': macroNote,
      };
}
