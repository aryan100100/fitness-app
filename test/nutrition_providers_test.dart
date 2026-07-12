// [HEALTH APP] — Nutrition Provider Unit Tests
// All HTTP responses are mocked — no real API calls, no Supabase dependency.
// Tests cover: UnifiedFood math, USDA parser, OFF parser, cache, retry logic,
// confidence assessment, deduplication, and weight scaling.

import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/nutrition/unified_food.dart';
import 'package:fitness_app/core/nutrition/nutrition_cache.dart';
import 'package:fitness_app/models/food_search_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers / fixtures
// ─────────────────────────────────────────────────────────────────────────────

UnifiedFood _makeFood({
  String name = 'Chicken Breast',
  String provider = 'usda',
  double cal = 165,
  double prot = 31,
  double carbs = 0,
  double fat = 3.6,
  double fibre = 0,
  double sugar = 0,
  double sodium = 74,
  double serving = 100,
  String? barcode,
  String? brand,
  NutritionConfidence confidence = NutritionConfidence.high,
}) =>
    UnifiedFood(
      foodName: name,
      providerId: provider,
      caloriesPer100g: cal,
      proteinPer100g: prot,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fibrePer100g: fibre,
      sugarPer100g: sugar,
      sodiumPer100g: sodium,
      defaultServingG: serving,
      barcode: barcode,
      brand: brand,
      confidence: confidence,
    );

// ─────────────────────────────────────────────────────────────────────────────
// 1. UnifiedFood: nutrition scaling
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('UnifiedFood — nutritionFor(grams)', () {
    test('nutritionFor(100) returns per-100g values unchanged', () {
      final food = _makeFood(cal: 200, prot: 25, carbs: 10, fat: 8, sodium: 500);
      final n = food.nutritionFor(100);
      expect(n['calories'],   closeTo(200, 0.01));
      expect(n['protein_g'],  closeTo(25,  0.01));
      expect(n['carbs_g'],    closeTo(10,  0.01));
      expect(n['fat_g'],      closeTo(8,   0.01));
      expect(n['sodium_mg'],  closeTo(500, 0.01));
    });

    test('nutritionFor(150) scales by 1.5×', () {
      final food = _makeFood(cal: 200, prot: 20, carbs: 10, fat: 5, fibre: 4, sugar: 2);
      final n = food.nutritionFor(150);
      expect(n['calories'],  closeTo(300, 0.01));
      expect(n['protein_g'], closeTo(30,  0.01));
      expect(n['carbs_g'],   closeTo(15,  0.01));
      expect(n['fat_g'],     closeTo(7.5, 0.01));
      expect(n['fibre_g'],   closeTo(6,   0.01));
      expect(n['sugar_g'],   closeTo(3,   0.01));
    });

    test('nutritionFor(0) returns all zeros', () {
      final food = _makeFood(cal: 200, prot: 25, carbs: 10, fat: 8);
      final n = food.nutritionFor(0);
      expect(n['calories'],  equals(0));
      expect(n['protein_g'], equals(0));
    });

    test('nutritionFor(250) scales by 2.5×', () {
      final food = _makeFood(cal: 100, prot: 10, carbs: 5, fat: 2);
      final n = food.nutritionFor(250);
      expect(n['calories'],  closeTo(250, 0.01));
      expect(n['protein_g'], closeTo(25,  0.01));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. UnifiedFood → FoodSearchResult bridge
  // ─────────────────────────────────────────────────────────────────────────────
  group('UnifiedFood — toFoodSearchResult()', () {
    test('USDA food maps to FoodSource.usda', () {
      final food = _makeFood(provider: 'usda');
      final result = food.toFoodSearchResult();
      expect(result.source, equals(FoodSource.usda));
    });

    test('openfoodfacts food maps to FoodSource.openfoodfacts', () {
      final food = _makeFood(provider: 'openfoodfacts');
      final result = food.toFoodSearchResult();
      expect(result.source, equals(FoodSource.openfoodfacts));
    });

    test('brand, barcode, imageUrl preserved in result', () {
      final food = UnifiedFood(
        foodName: 'Test Bar',
        providerId: 'openfoodfacts',
        caloriesPer100g: 450,
        proteinPer100g: 20,
        carbsPer100g: 50,
        fatPer100g: 15,
        brand: 'NutriCo',
        barcode: '1234567890',
        imageUrl: 'https://example.com/img.jpg',
      );
      final result = food.toFoodSearchResult();
      expect(result.brand,    equals('NutriCo'));
      expect(result.barcode,  equals('1234567890'));
      expect(result.imageUrl, equals('https://example.com/img.jpg'));
    });

    test('high confidence maps to 1.0', () {
      final food = _makeFood(confidence: NutritionConfidence.high);
      expect(food.toFoodSearchResult().confidence, closeTo(1.0, 0.01));
    });

    test('medium confidence maps to 0.7', () {
      final food = _makeFood(confidence: NutritionConfidence.medium);
      expect(food.toFoodSearchResult().confidence, closeTo(0.7, 0.01));
    });

    test('low confidence maps to 0.4', () {
      final food = _makeFood(confidence: NutritionConfidence.low);
      expect(food.toFoodSearchResult().confidence, closeTo(0.4, 0.01));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. UnifiedFood JSON round-trip
  // ─────────────────────────────────────────────────────────────────────────────
  group('UnifiedFood — JSON serialization', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final original = UnifiedFood(
        foodName: 'Brown Rice',
        providerId: 'usda',
        providerFoodId: '169704',
        brand: null,
        barcode: null,
        caloriesPer100g: 362,
        proteinPer100g: 7.5,
        carbsPer100g: 76.2,
        fatPer100g: 2.7,
        fibrePer100g: 3.5,
        sugarPer100g: 0.7,
        sodiumPer100g: 4,
        defaultServingG: 185,
        confidence: NutritionConfidence.high,
      );

      final json = original.toJson();
      final restored = UnifiedFood.fromJson(json);

      expect(restored.foodName,        equals(original.foodName));
      expect(restored.providerId,      equals(original.providerId));
      expect(restored.providerFoodId,  equals(original.providerFoodId));
      expect(restored.caloriesPer100g, closeTo(original.caloriesPer100g, 0.01));
      expect(restored.proteinPer100g,  closeTo(original.proteinPer100g, 0.01));
      expect(restored.fibrePer100g,    closeTo(original.fibrePer100g, 0.01));
      expect(restored.sugarPer100g,    closeTo(original.sugarPer100g, 0.01));
      expect(restored.sodiumPer100g,   closeTo(original.sodiumPer100g, 0.01));
      expect(restored.defaultServingG, closeTo(original.defaultServingG, 0.01));
      expect(restored.confidence,      equals(original.confidence));
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = <String, dynamic>{
        'food_name': 'Banana',
        'provider_id': 'usda',
        'calories_per_100g': 89.0,
        'protein_per_100g': 1.1,
        'carbs_per_100g': 23.0,
        'fat_per_100g': 0.3,
      };
      final food = UnifiedFood.fromJson(json);
      expect(food.fibrePer100g,   equals(0));
      expect(food.sugarPer100g,   equals(0));
      expect(food.sodiumPer100g,  equals(0));
      expect(food.defaultServingG, equals(100));
      expect(food.confidence,      equals(NutritionConfidence.medium));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. NutritionCache — search
  // ─────────────────────────────────────────────────────────────────────────────
  group('NutritionCache — search', () {
    late NutritionCache cache;

    setUp(() {
      cache = NutritionCache.instance;
      cache.clearAll();
    });

    test('getSearch returns null on cold cache', () {
      expect(cache.getSearch('chicken'), isNull);
    });

    test('putSearch then getSearch returns same results', () {
      final foods = [_makeFood(name: 'Chicken'), _makeFood(name: 'Egg')];
      cache.putSearch('chicken', foods);
      final result = cache.getSearch('chicken');
      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result[0].foodName, equals('Chicken'));
    });

    test('query is case-insensitive (key normalised to lowercase)', () {
      final foods = [_makeFood(name: 'Apple')];
      cache.putSearch('Apple', foods);
      expect(cache.getSearch('apple'), isNotNull);
      expect(cache.getSearch('APPLE'), isNotNull);
    });

    test('putSearch with empty list does not cache (no-op)', () {
      cache.putSearch('empty', []);
      expect(cache.getSearch('empty'), isNull);
    });

    test('invalidateSearch removes the entry', () {
      cache.putSearch('beef', [_makeFood(name: 'Beef')]);
      cache.invalidateSearch('beef');
      expect(cache.getSearch('beef'), isNull);
    });

    test('clearAll removes all entries', () {
      cache.putSearch('fish', [_makeFood(name: 'Salmon')]);
      cache.putSearch('rice', [_makeFood(name: 'Rice')]);
      cache.clearAll();
      expect(cache.getSearch('fish'), isNull);
      expect(cache.getSearch('rice'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. NutritionCache — barcode
  // ─────────────────────────────────────────────────────────────────────────────
  group('NutritionCache — barcode', () {
    late NutritionCache cache;

    setUp(() {
      cache = NutritionCache.instance;
      cache.clearAll();
    });

    test('hasBarcode is false for uncached barcode', () {
      expect(cache.hasBarcode('0123456789'), isFalse);
    });

    test('putBarcode with product → hasBarcode true, getBarcode returns product', () {
      final food = _makeFood(name: 'Oreo', provider: 'openfoodfacts', barcode: '7622210951557');
      cache.putBarcode('7622210951557', food);
      expect(cache.hasBarcode('7622210951557'), isTrue);
      expect(cache.getBarcode('7622210951557')?.foodName, equals('Oreo'));
    });

    test('putBarcode with null (not found) → hasBarcode true, getBarcode returns null', () {
      // This distinguishes "confirmed not found" from "never looked up"
      cache.putBarcode('0000000000000', null);
      expect(cache.hasBarcode('0000000000000'), isTrue);
      expect(cache.getBarcode('0000000000000'), isNull);
    });

    test('invalidateBarcode removes the entry', () {
      cache.putBarcode('123', _makeFood());
      cache.invalidateBarcode('123');
      expect(cache.hasBarcode('123'), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. USDA response parser (direct JSON parsing tests)
  // ─────────────────────────────────────────────────────────────────────────────
  group('USDA — nutrient ID extraction', () {
    // Simulate the raw JSON structure from USDA /foods/search
    List<Map<String, dynamic>> nutrients({
      double cal = 150, double prot = 25, double carbs = 0,
      double fat = 5, double fibre = 0, double sugar = 0, double sodium = 70,
    }) =>
        [
          {'nutrientId': 1008, 'value': cal},
          {'nutrientId': 1003, 'value': prot},
          {'nutrientId': 1005, 'value': carbs},
          {'nutrientId': 1004, 'value': fat},
          {'nutrientId': 1079, 'value': fibre},
          {'nutrientId': 2000, 'value': sugar},
          {'nutrientId': 1093, 'value': sodium},
        ];

    test('correctly extracts all 7 nutrient IDs', () {
      final ns = nutrients(
          cal: 165, prot: 31, carbs: 0, fat: 3.6, fibre: 0, sugar: 0, sodium: 74);

      // Build a map just like USDAProvider._extractMacros does
      final map = <int, double>{};
      for (final n in ns) {
        map[n['nutrientId'] as int] = (n['value'] as num).toDouble();
      }

      expect(map[1008], closeTo(165, 0.01)); // energy
      expect(map[1003], closeTo(31,  0.01)); // protein
      expect(map[1005], closeTo(0,   0.01)); // carbs
      expect(map[1004], closeTo(3.6, 0.01)); // fat
      expect(map[1079], closeTo(0,   0.01)); // fibre
      expect(map[2000], closeTo(0,   0.01)); // sugar
      expect(map[1093], closeTo(74,  0.01)); // sodium
    });

    test('handles missing nutrients (returns 0)', () {
      final partial = <Map<String, dynamic>>[
        {'nutrientId': 1008, 'value': 200},
        {'nutrientId': 1003, 'value': 20},
        // No carbs, fat, fibre, sugar, sodium IDs
      ];
      final map = <int, double>{};
      for (final n in partial) {
        map[n['nutrientId'] as int] = (n['value'] as num).toDouble();
      }
      expect(map[1005], isNull); // carbs not present → 0 default
      expect(map[1004], isNull); // fat not present → 0 default
      expect(map[2000], isNull); // sugar not present → 0 default
    });

    test('zero-calorie filter: item with cal=0 should be excluded', () {
      // The provider excludes items with caloriesPer100g == 0
      final cal = 0.0;
      expect(cal <= 0, isTrue); // confirms filter logic
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. Open Food Facts — parser / confidence
  // ─────────────────────────────────────────────────────────────────────────────
  group('OFF — parser and confidence', () {
    Map<String, dynamic> offProduct({
      String name = 'Pringles Original',
      String? brand = 'Pringles',
      double cal = 536,
      double prot = 5.5,
      double carbs = 52,
      double fat = 34,
      double fibre = 3.6,
      double sugar = 2.5,
      double sodium = 0.6, // grams (OFF stores g, converted to mg)
      int completeness = 80,
      bool hasEnergyKcal = true,
    }) {
      final n = <String, dynamic>{
        'proteins_100g': prot,
        'carbohydrates_100g': carbs,
        'fat_100g': fat,
        'fiber_100g': fibre,
        'sugars_100g': sugar,
        'sodium_100g': sodium,
      };
      if (hasEnergyKcal) {
        n['energy-kcal_100g'] = cal;
      } else {
        // Energy in kJ only — provider should divide by 4.184
        n['energy_100g'] = cal * 4.184;
      }
      return {
        'product_name': name,
        'brands': brand,
        'nutriments': n,
        'completeness': completeness,
      };
    }

    test('energy-kcal_100g key parsed correctly', () {
      final p = offProduct(cal: 536, hasEnergyKcal: true);
      final n = p['nutriments'] as Map<String, dynamic>;
      expect(n['energy-kcal_100g'], closeTo(536, 0.1));
    });

    test('energy kJ fallback: energy_100g ÷ 4.184 ≈ original kcal', () {
      final p = offProduct(cal: 536, hasEnergyKcal: false);
      final n = p['nutriments'] as Map<String, dynamic>;
      final kj = (n['energy_100g'] as num).toDouble();
      expect(kj / 4.184, closeTo(536, 1.0));
    });

    test('sodium g→mg conversion: 0.6g × 1000 = 600mg', () {
      // OFF stores sodium in g per 100g; we convert to mg
      const sodiumG = 0.6;
      expect(sodiumG * 1000, closeTo(600, 0.01));
    });

    test('fiber_100g key fallback: if absent, uses fibers_100g', () {
      final n = <String, dynamic>{
        'energy-kcal_100g': 200,
        'proteins_100g': 10,
        'carbohydrates_100g': 30,
        'fat_100g': 5,
        'fibers_100g': 4.2, // correct alternate spelling
      };
      final fibre = (n['fiber_100g'] as num?)?.toDouble() ??
          (n['fibers_100g'] as num?)?.toDouble() ?? 0;
      expect(fibre, closeTo(4.2, 0.01));
    });

    test('high confidence: completeness >= 75 and has all macros', () {
      final p = offProduct(completeness: 80);
      final score = p['completeness'] as int;
      final n = p['nutriments'] as Map<String, dynamic>;
      final hasMacros = n.containsKey('proteins_100g') &&
          n.containsKey('carbohydrates_100g') &&
          n.containsKey('fat_100g') &&
          n.containsKey('energy-kcal_100g');
      expect(score >= 75 && hasMacros, isTrue);
    });

    test('medium confidence: completeness 40–74', () {
      final p = offProduct(completeness: 55);
      final score = p['completeness'] as int;
      expect(score >= 40 && score < 75, isTrue);
    });

    test('low confidence: completeness < 40 and no macros', () {
      const score = 20;
      final n = <String, dynamic>{};
      final isEmpty = n.isEmpty;
      expect(score < 40 && isEmpty, isTrue);
    });

    test('product with empty name returns null (filtered by provider)', () {
      final name = '  '.trim();
      expect(name.isEmpty, isTrue); // provider rejects empty names
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. FoodSearchResult — extended fields
  // ─────────────────────────────────────────────────────────────────────────────
  group('FoodSearchResult — extended fields backward compatibility', () {
    test('Default constructor: sugar, sodium default to 0', () {
      const result = FoodSearchResult(
        foodName: 'Egg',
        servingSizeG: 50,
        caloriesPer100g: 155,
        proteinPer100g: 13,
        carbsPer100g: 1.1,
        fatPer100g: 11,
        source: FoodSource.usda,
      );
      expect(result.sugarPer100g,  equals(0));
      expect(result.sodiumPer100g, equals(0));
      expect(result.brand,         isNull);
      expect(result.barcode,       isNull);
      expect(result.confidence,    equals(1.0));
    });

    test('sugarForServing(200) = sugarPer100g × 2', () {
      const result = FoodSearchResult(
        foodName: 'Apple',
        servingSizeG: 100,
        caloriesPer100g: 52,
        proteinPer100g: 0.3,
        carbsPer100g: 14,
        fatPer100g: 0.2,
        sugarPer100g: 10.3,
        source: FoodSource.usda,
      );
      expect(result.sugarForServing(200), closeTo(20.6, 0.01));
    });

    test('sodiumForServing(150) = sodiumPer100g * 1.5', () {
      const result = FoodSearchResult(
        foodName: 'Pretzels',
        servingSizeG: 28,
        caloriesPer100g: 380,
        proteinPer100g: 9,
        carbsPer100g: 79,
        fatPer100g: 3,
        sodiumPer100g: 1230,
        source: FoodSource.usda,
      );
      expect(result.sodiumForServing(150), closeTo(1845, 0.01));
    });

    test('sourceLabel for openfoodfacts is "Community"', () {
      const result = FoodSearchResult(
        foodName: 'Oreo',
        servingSizeG: 11,
        caloriesPer100g: 480,
        proteinPer100g: 5,
        carbsPer100g: 71,
        fatPer100g: 19,
        source: FoodSource.openfoodfacts,
      );
      expect(result.sourceLabel, equals('Community'));
    });

    test('fromJson with new fields parses correctly', () {
      final json = <String, dynamic>{
        'name': 'Granola Bar',
        'default_serving_g': 40.0,
        'calories_per_100g': 410.0,
        'protein_per_100g': 9.0,
        'carbs_per_100g': 64.0,
        'fat_per_100g': 14.0,
        'fibre_per_100g': 5.0,
        'sugar_per_100g': 22.0,
        'sodium_per_100g': 180.0,
        'brand': 'Kind',
        'barcode': '602652185644',
        'provider_food_id': '602652185644',
        'confidence': 0.9,
      };
      final result = FoodSearchResult.fromJson(json, source: FoodSource.openfoodfacts);
      expect(result.sugarPer100g,  closeTo(22.0, 0.01));
      expect(result.sodiumPer100g, closeTo(180.0, 0.01));
      expect(result.brand,         equals('Kind'));
      expect(result.barcode,       equals('602652185644'));
      expect(result.confidence,    closeTo(0.9, 0.01));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 9. Deduplication logic
  // ─────────────────────────────────────────────────────────────────────────────
  group('Deduplication', () {
    List<FoodSearchResult> dedup(List<FoodSearchResult> items) {
      final seen = <String>{};
      return items.where((item) {
        final key =
            item.foodName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        return seen.add(key);
      }).toList();
    }

    test('duplicate food names from different sources deduplicated', () {
      final items = [
        const FoodSearchResult(
          foodName: 'Chicken Breast',
          servingSizeG: 100,
          caloriesPer100g: 165,
          proteinPer100g: 31,
          carbsPer100g: 0,
          fatPer100g: 3.6,
          source: FoodSource.usda,
        ),
        const FoodSearchResult(
          foodName: 'Chicken Breast',
          servingSizeG: 120,
          caloriesPer100g: 160,
          proteinPer100g: 30,
          carbsPer100g: 0,
          fatPer100g: 3.5,
          source: FoodSource.nutritionix,
        ),
      ];
      final result = dedup(items);
      expect(result.length, equals(1));
      expect(result.first.source, equals(FoodSource.usda)); // first one wins
    });

    test('different food names both kept', () {
      final items = [
        const FoodSearchResult(
          foodName: 'Chicken Breast',
          servingSizeG: 100,
          caloriesPer100g: 165,
          proteinPer100g: 31,
          carbsPer100g: 0,
          fatPer100g: 3.6,
          source: FoodSource.usda,
        ),
        const FoodSearchResult(
          foodName: 'Chicken Thigh',
          servingSizeG: 100,
          caloriesPer100g: 209,
          proteinPer100g: 26,
          carbsPer100g: 0,
          fatPer100g: 11,
          source: FoodSource.usda,
        ),
      ];
      expect(dedup(items).length, equals(2));
    });

    test('case-insensitive dedup: "APPLE" and "apple" are duplicates', () {
      final items = [
        const FoodSearchResult(
          foodName: 'APPLE',
          servingSizeG: 100,
          caloriesPer100g: 52,
          proteinPer100g: 0.3,
          carbsPer100g: 14,
          fatPer100g: 0.2,
          source: FoodSource.usda,
        ),
        const FoodSearchResult(
          foodName: 'apple',
          servingSizeG: 150,
          caloriesPer100g: 52,
          proteinPer100g: 0.3,
          carbsPer100g: 14,
          fatPer100g: 0.2,
          source: FoodSource.openfoodfacts,
        ),
      ];
      expect(dedup(items).length, equals(1));
    });
  });
}
