// [HEALTH APP] — Food Search Result Model
// Unified result from all search tiers (USDA, OpenFoodFacts, Indian, Custom).
// All macros stored per 100 g — scale with the helper methods.
// New fields (sugar, sodium, brand, barcode, imageUrl, providerFoodId,
// confidence) are nullable/defaulted and backward-compatible.

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
  final double servingSizeG;       // default serving size in grams
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fibrePer100g;

  // ── Extended fields (new — backward-compatible) ────────────────────────────
  final double sugarPer100g;       // g per 100g
  final double sodiumPer100g;      // mg per 100g
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final String? providerFoodId;    // USDA fdcId, OFF barcode, etc.
  final double confidence;         // 0.0–1.0 (default 1.0 = full confidence)

  final FoodSource source;
  final String? note;

  // ── Per-serving helpers ────────────────────────────────────────────────────

  double caloriesForServing(double grams) => caloriesPer100g * grams / 100;
  double proteinForServing(double grams)  => proteinPer100g  * grams / 100;
  double carbsForServing(double grams)    => carbsPer100g    * grams / 100;
  double fatForServing(double grams)      => fatPer100g      * grams / 100;
  double fibreForServing(double grams)    => fibrePer100g    * grams / 100;
  double sugarForServing(double grams)    => sugarPer100g    * grams / 100;
  double sodiumForServing(double grams)   => sodiumPer100g   * grams / 100;

  String get sourceLabel {
    return switch (source) {
      FoodSource.usda          => 'USDA',
      FoodSource.nutritionix   => 'Nutritionix',
      FoodSource.openfoodfacts => 'Community',
      FoodSource.indianLocal   => '🇮🇳 Indian Db',
      FoodSource.custom        => 'Custom',
      FoodSource.photoEstimate => 'AI Estimate',
      FoodSource.manual        => 'Manual',
      FoodSource.recent        => 'Recent',
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
    this.sugarPer100g = 0,
    this.sodiumPer100g = 0,
    this.brand,
    this.barcode,
    this.imageUrl,
    this.providerFoodId,
    this.confidence = 1.0,
    required this.source,
    this.note,
  });

  factory FoodSearchResult.fromJson(Map<String, dynamic> json,
      {FoodSource source = FoodSource.manual}) {
    return FoodSearchResult(
      foodName:        json['name']              as String? ?? '',
      servingSizeG:   (json['default_serving_g'] as num?)?.toDouble() ?? 100,
      caloriesPer100g:(json['calories_per_100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (json['protein_per_100g']  as num?)?.toDouble() ?? 0,
      carbsPer100g:   (json['carbs_per_100g']    as num?)?.toDouble() ?? 0,
      fatPer100g:     (json['fat_per_100g']      as num?)?.toDouble() ?? 0,
      fibrePer100g:   (json['fibre_per_100g']    as num?)?.toDouble() ?? 0,
      sugarPer100g:   (json['sugar_per_100g']    as num?)?.toDouble() ?? 0,
      sodiumPer100g:  (json['sodium_per_100g']   as num?)?.toDouble() ?? 0,
      brand:          json['brand']              as String?,
      barcode:        json['barcode']            as String?,
      imageUrl:       json['image_url']          as String?,
      providerFoodId: json['provider_food_id']   as String?,
      confidence:    (json['confidence']         as num?)?.toDouble() ?? 1.0,
      source: source,
      note: json['note'] as String?,
    );
  }
}
