// [HEALTH APP] — Food Search Result Model
// Unified result from all search tiers (USDA, Nutritionix, OpenFoodFacts, Indian, Custom).

enum FoodSource {
  usda,
  nutritionix,
  openfoodfacts,
  indianLocal,
  custom,
  photoEstimate,
  manual,
  recent,
}

class FoodSearchResult {
  final String foodName;
  final double servingSizeG;      // default serving size in grams
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fibrePer100g;
  final FoodSource source;
  final String? note;             // e.g. Indian food variation note

  // Computed for a given serving
  double caloriesForServing(double grams) =>
      (caloriesPer100g * grams / 100);
  double proteinForServing(double grams) =>
      (proteinPer100g * grams / 100);
  double carbsForServing(double grams) =>
      (carbsPer100g * grams / 100);
  double fatForServing(double grams) =>
      (fatPer100g * grams / 100);
  double fibreForServing(double grams) =>
      (fibrePer100g * grams / 100);

  String get sourceLabel {
    return switch (source) {
      FoodSource.usda         => 'USDA',
      FoodSource.nutritionix  => 'Nutritionix',
      FoodSource.openfoodfacts => 'Community',
      FoodSource.indianLocal  => '🇮🇳 Indian Db',
      FoodSource.custom       => 'Custom',
      FoodSource.photoEstimate => 'AI Estimate',
      FoodSource.manual       => 'Manual',
      FoodSource.recent       => 'Recent',
    };
  }

  const FoodSearchResult({
    required this.foodName,
    required this.servingSizeG,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fibrePer100g = 0,
    required this.source,
    this.note,
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json,
      {FoodSource source = FoodSource.manual}) {
    return FoodSearchResult(
      foodName: json['name'] as String? ?? '',
      servingSizeG: (json['default_serving_g'] as num?)?.toDouble() ?? 100,
      caloriesPer100g:
          (json['calories_per_100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g:
          (json['protein_per_100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (json['carbs_per_100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (json['fat_per_100g'] as num?)?.toDouble() ?? 0,
      fibrePer100g: (json['fibre_per_100g'] as num?)?.toDouble() ?? 0,
      source: source,
      note: json['note'] as String?,
    );
  }
}
