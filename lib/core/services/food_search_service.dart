// [HEALTH APP] — Food Search Service
// Orchestrates 4 tiers of food data:
//   Tier 0 — Recent foods from Supabase (instant)
//   Tier 1 — USDA FoodData Central (whole foods, lab-measured)
//   Tier 2 — Nutritionix (branded + restaurant foods)
//   Tier 3 — Open Food Facts (international fallback, community data)
//   Local  — Indian foods JSON (offline, instant)
// Each tier has independent try/catch — one failure never blocks others.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_search_result.dart';
import '../../models/food_log_model.dart';

class FoodSearchService {
  FoodSearchService._();
  static final FoodSearchService instance = FoodSearchService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Cached Indian foods list (loaded once)
  List<FoodSearchResult>? _indianFoodsCache;

  // ---------------------------------------------------------------------------
  // Master search — orchestrates all tiers
  // ---------------------------------------------------------------------------
  Future<List<FoodSearchResult>> search(
      String query, String userId) async {
    if (query.trim().length < 2) return [];

    // Tier 1 + 2 in parallel
    final futures = await Future.wait([
      _searchUSDA(query),
      _searchNutritionix(query),
      _searchIndianLocal(query),
    ]);

    final usda         = futures[0];
    final nutritionix  = futures[1];
    final indian       = futures[2];

    // Merge and deduplicate Tier 1 + 2
    final merged = _deduplicate([...usda, ...nutritionix]);

    // Add Tier 3 (Open Food Facts) only if fewer than 5 results
    List<FoodSearchResult> openFF = [];
    if (merged.length < 5) {
      openFF = await _searchOpenFoodFacts(query);
    }

    // Final ranked list:
    // USDA → Nutritionix → Indian local → OpenFoodFacts
    final ranked = <FoodSearchResult>[
      ...merged.where((r) => r.source == FoodSource.usda),
      ...merged.where((r) => r.source == FoodSource.nutritionix),
      ...indian,
      ...openFF,
    ];

    return ranked.take(20).toList();
  }

  // ---------------------------------------------------------------------------
  // Tier 0 — Recent foods (last 8 distinct, by name)
  // ---------------------------------------------------------------------------
  Future<List<FoodLogModel>> getRecentFoods(
      String userId, {int limit = 8}) async {
    try {
      final data = await _client
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final seen = <String>{};
      final result = <FoodLogModel>[];
      for (final row in data as List) {
        final model = FoodLogModel.fromJson(row);
        if (seen.add(model.foodName) && result.length < limit) {
          result.add(model);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Tier 0 — Usual foods (top 5 by log frequency)
  // ---------------------------------------------------------------------------
  Future<List<FoodLogModel>> getUsualFoods(
      String userId, {int limit = 5}) async {
    try {
      final data = await _client
          .from('food_logs')
          .select('food_name, calories, protein_g, carbs_g, fat_g, fibre_g, quantity_g, food_source')
          .eq('user_id', userId);

      final counts = <String, int>{};
      final samples = <String, FoodLogModel>{};

      for (final row in data as List) {
        final model = FoodLogModel.fromJson({
          ...row,
          'id': null,
          'user_id': userId,
          'date': '',
          'meal_type': 'snack',
          'is_photo_estimate': false,
        });
        counts[model.foodName] = (counts[model.foodName] ?? 0) + 1;
        samples[model.foodName] = model;
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted
          .take(limit)
          .map((e) => samples[e.key]!)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Tier 1 — USDA FoodData Central
  // ---------------------------------------------------------------------------
  Future<List<FoodSearchResult>> _searchUSDA(String query) async {
    try {
      final apiKey = dotenv.env['USDA_API_KEY'] ?? '';
      if (apiKey.isEmpty) return [];

      final uri = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search'
        '?query=${Uri.encodeComponent(query)}'
        '&api_key=$apiKey'
        '&dataType=Foundation,SR%20Legacy'
        '&pageSize=8',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = json['foods'] as List? ?? [];

      return foods.map<FoodSearchResult>((f) {
        final nutrients = (f['foodNutrients'] as List? ?? []);
        double cal = 0, prot = 0, carbs = 0, fat = 0, fibre = 0;
        for (final n in nutrients) {
          final idVal = n['nutrientId'] as int? ?? 0;
          final val = (n['value'] as num?)?.toDouble() ?? 0;
          if (idVal == 1008) cal = val;
          if (idVal == 1003) prot = val;
          if (idVal == 1005) carbs = val;
          if (idVal == 1004) fat = val;
          if (idVal == 1079) fibre = val;
        }
        return FoodSearchResult(
          foodName: f['description'] as String? ?? '',
          servingSizeG: 100,
          caloriesPer100g: cal,
          proteinPer100g: prot,
          carbsPer100g: carbs,
          fatPer100g: fat,
          fibrePer100g: fibre,
          source: FoodSource.usda,
        );
      }).where((r) => r.foodName.isNotEmpty && r.caloriesPer100g > 0).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Tier 2 — Nutritionix
  // ---------------------------------------------------------------------------
  Future<List<FoodSearchResult>> _searchNutritionix(String query) async {
    try {
      final appId  = dotenv.env['NUTRITIONIX_APP_ID'] ?? '';
      final appKey = dotenv.env['NUTRITIONIX_API_KEY'] ?? '';
      if (appId.isEmpty || appKey.isEmpty) return [];

      final uri = Uri.parse(
          'https://trackapi.nutritionix.com/v2/search/instant?query=${Uri.encodeComponent(query)}');

      final response = await http.get(uri, headers: {
        'x-app-id': appId,
        'x-app-key': appKey,
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final branded = json['branded'] as List? ?? [];
      final common  = json['common']  as List? ?? [];
      final all = [...common.take(4), ...branded.take(4)];

      return all.map<FoodSearchResult>((item) {
        final servingWt   = (item['serving_weight_grams'] as num?)?.toDouble() ?? 100;
        final servingCal  = (item['nf_calories'] as num?)?.toDouble() ?? 0;

        // Convert to per-100g values (Nutritionix returns per-serving)
        final factor = servingWt > 0 ? 100 / servingWt : 1;

        return FoodSearchResult(
          foodName: item['food_name'] as String? ?? '',
          servingSizeG: servingWt,
          caloriesPer100g: servingCal * factor,
          proteinPer100g:
              ((item['nf_protein'] as num?)?.toDouble() ?? 0) * factor,
          carbsPer100g:
              ((item['nf_total_carbohydrate'] as num?)?.toDouble() ?? 0) *
                  factor,
          fatPer100g:
              ((item['nf_total_fat'] as num?)?.toDouble() ?? 0) * factor,
          fibrePer100g:
              ((item['nf_dietary_fiber'] as num?)?.toDouble() ?? 0) * factor,
          source: FoodSource.nutritionix,
        );
      }).where(
          (r) => r.foodName.isNotEmpty && r.caloriesPer100g > 0).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Tier 3 — Open Food Facts (fallback)
  // ---------------------------------------------------------------------------
  Future<List<FoodSearchResult>> _searchOpenFoodFacts(
      String query) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&json=1&page_size=5'
        '&fields=product_name,nutriments',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final products = json['products'] as List? ?? [];

      return products.map<FoodSearchResult>((p) {
        final n = p['nutriments'] as Map<String, dynamic>? ?? {};
        return FoodSearchResult(
          foodName: p['product_name'] as String? ?? '',
          servingSizeG: 100,
          caloriesPer100g:   (n['energy-kcal_100g'] as num?)?.toDouble() ?? 0,
          proteinPer100g:    (n['proteins_100g']    as num?)?.toDouble() ?? 0,
          carbsPer100g:      (n['carbohydrates_100g'] as num?)?.toDouble() ?? 0,
          fatPer100g:        (n['fat_100g']          as num?)?.toDouble() ?? 0,
          fibrePer100g:      (n['fiber_100g']        as num?)?.toDouble() ?? 0,
          source: FoodSource.openfoodfacts,
        );
      }).where(
          (r) => r.foodName.isNotEmpty && r.caloriesPer100g > 0).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Local — Indian foods JSON (offline, instant)
  // ---------------------------------------------------------------------------
  Future<List<FoodSearchResult>> _searchIndianLocal(
      String query) async {
    try {
      final all = await _loadIndianFoods();
      final q = query.toLowerCase();
      return all
          .where((f) => f.foodName.toLowerCase().contains(q))
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<FoodSearchResult>> _loadIndianFoods() async {
    if (_indianFoodsCache != null) return _indianFoodsCache!;
    try {
      final raw = await rootBundle.loadString('assets/indian_foods.json');
      final list = jsonDecode(raw) as List;
      _indianFoodsCache = list
          .map((e) => FoodSearchResult.fromJson(e,
              source: FoodSource.indianLocal))
          .toList();
      return _indianFoodsCache!;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Deduplicate merged results by normalised food name
  // ---------------------------------------------------------------------------
  List<FoodSearchResult> _deduplicate(List<FoodSearchResult> items) {
    final seen = <String>{};
    return items.where((item) {
      final key = item.foodName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      return seen.add(key);
    }).toList();
  }
}
