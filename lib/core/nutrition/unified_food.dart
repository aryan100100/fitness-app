// [HEALTH APP] — UnifiedFood Model
// The single normalized nutrition model returned by ALL providers.
// Regardless of source (USDA, Open Food Facts, Nutritionix, etc.), the
// app always receives a UnifiedFood. All values are stored per 100 g.

import '../../models/food_search_result.dart';
import '../../models/food_log_model.dart';

/// Confidence in the completeness/accuracy of the nutrition data.
enum NutritionConfidence { high, medium, low }

/// Normalized nutrition model — source-agnostic.
/// All macros are per 100 g. Use [nutritionFor] to scale to any serving.
class UnifiedFood {
  // ── Identity ────────────────────────────────────────────────────────────────
  final String foodName;
  final String? brand;
  final String? barcode;
  final String? imageUrl;
  final String providerId;       // 'usda' | 'openfoodfacts' | 'nutritionix' | 'indian_local'
  final String? providerFoodId;  // USDA fdcId, OFF barcode, etc.

  // ── Macros per 100 g ────────────────────────────────────────────────────────
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fibrePer100g;
  final double sugarPer100g;
  final double sodiumPer100g; // mg per 100 g

  // ── Serving ─────────────────────────────────────────────────────────────────
  final double defaultServingG; // suggested serving in grams (default 100)

  // ── Meta ────────────────────────────────────────────────────────────────────
  final NutritionConfidence confidence;
  final String? note;

  const UnifiedFood({
    required this.foodName,
    required this.providerId,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fibrePer100g = 0,
    this.sugarPer100g = 0,
    this.sodiumPer100g = 0,
    this.defaultServingG = 100,
    this.brand,
    this.barcode,
    this.imageUrl,
    this.providerFoodId,
    this.confidence = NutritionConfidence.medium,
    this.note,
  });

  // ── Scaled nutrition ────────────────────────────────────────────────────────

  /// Returns all macro values scaled to [grams].
  Map<String, double> nutritionFor(double grams) {
    final f = grams / 100.0;
    return {
      'calories': caloriesPer100g * f,
      'protein_g': proteinPer100g * f,
      'carbs_g': carbsPer100g * f,
      'fat_g': fatPer100g * f,
      'fibre_g': fibrePer100g * f,
      'sugar_g': sugarPer100g * f,
      'sodium_mg': sodiumPer100g * f,
    };
  }

  // ── Bridge: backward-compatible ─────────────────────────────────────────────

  /// Converts to the existing [FoodSearchResult] model used throughout the app.
  FoodSearchResult toFoodSearchResult() {
    return FoodSearchResult(
      foodName: foodName,
      servingSizeG: defaultServingG,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fibrePer100g: fibrePer100g,
      sugarPer100g: sugarPer100g,
      sodiumPer100g: sodiumPer100g,
      brand: brand,
      barcode: barcode,
      imageUrl: imageUrl,
      providerFoodId: providerFoodId,
      confidence: _mapConfidence(confidence),
      source: _mapSource(providerId),
      note: note,
    );
  }

  /// Creates a [FoodLogModel] ready to insert into Supabase.
  FoodLogModel toFoodLogModel({
    required String userId,
    required String date,
    required String mealType,
    required double grams,
  }) {
    final n = nutritionFor(grams);
    return FoodLogModel(
      userId: userId,
      date: date,
      mealType: mealType,
      foodName: foodName,
      quantityG: grams,
      calories: n['calories']!,
      proteinG: n['protein_g']!,
      carbsG: n['carbs_g']!,
      fatG: n['fat_g']!,
      fibreG: n['fibre_g']!,
      isPhotoEstimate: false,
      foodSource: providerId,
    );
  }

  // ── JSON serialization (for Supabase cache) ──────────────────────────────────

  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'provider_id': providerId,
        'provider_food_id': providerFoodId,
        'brand': brand,
        'barcode': barcode,
        'image_url': imageUrl,
        'calories_per_100g': caloriesPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
        'fibre_per_100g': fibrePer100g,
        'sugar_per_100g': sugarPer100g,
        'sodium_per_100g': sodiumPer100g,
        'default_serving_g': defaultServingG,
        'confidence': confidence.name,
        'note': note,
      };

  factory UnifiedFood.fromJson(Map<String, dynamic> j) => UnifiedFood(
        foodName: j['food_name'] as String? ?? '',
        providerId: j['provider_id'] as String? ?? 'unknown',
        providerFoodId: j['provider_food_id'] as String?,
        brand: j['brand'] as String?,
        barcode: j['barcode'] as String?,
        imageUrl: j['image_url'] as String?,
        caloriesPer100g: _d(j['calories_per_100g']),
        proteinPer100g: _d(j['protein_per_100g']),
        carbsPer100g: _d(j['carbs_per_100g']),
        fatPer100g: _d(j['fat_per_100g']),
        fibrePer100g: _d(j['fibre_per_100g']),
        sugarPer100g: _d(j['sugar_per_100g']),
        sodiumPer100g: _d(j['sodium_per_100g']),
        defaultServingG: _d(j['default_serving_g'], fallback: 100),
        confidence: NutritionConfidence.values.firstWhere(
          (e) => e.name == (j['confidence'] as String? ?? 'medium'),
          orElse: () => NutritionConfidence.medium,
        ),
        note: j['note'] as String?,
      );

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static double _d(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    return (v as num).toDouble();
  }

  static FoodSource _mapSource(String providerId) {
    return switch (providerId) {
      'usda' => FoodSource.usda,
      'openfoodfacts' => FoodSource.openfoodfacts,
      'nutritionix' => FoodSource.nutritionix,
      'indian_local' => FoodSource.indianLocal,
      'custom' => FoodSource.custom,
      'photo_estimate' => FoodSource.photoEstimate,
      _ => FoodSource.manual,
    };
  }

  static double _mapConfidence(NutritionConfidence c) {
    return switch (c) {
      NutritionConfidence.high => 1.0,
      NutritionConfidence.medium => 0.7,
      NutritionConfidence.low => 0.4,
    };
  }
}
