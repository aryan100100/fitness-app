// [HEALTH APP] — Nutrition Provider Interface
// Abstract contract that all nutrition data providers must implement.
// New providers (Nutritionix, Edamam, FatSecret, etc.) implement this
// interface and can be dropped into NutritionOrchestrator without changes
// to any call site.

import 'unified_food.dart';

/// Abstract base for any nutrition data provider.
abstract class NutritionProvider {
  /// Short identifier used in logs, cache keys, and FoodSource labels.
  /// E.g. 'usda', 'openfoodfacts', 'nutritionix'
  String get providerId;

  /// Human-readable display name.
  String get displayName;

  /// Search for foods by text query.
  /// Returns an empty list on any error — never throws.
  Future<List<UnifiedFood>> searchFoods(String query);

  /// Look up a single product by barcode (EAN/UPC).
  /// Returns null if not found or on error — never throws.
  Future<UnifiedFood?> lookupBarcode(String barcode);

  /// Fetch full nutrition details for a specific provider food ID.
  /// Used to enrich a search result with complete nutrient data.
  /// Returns null if not found or on error — never throws.
  Future<UnifiedFood?> getFoodDetails(String providerFoodId);
}
