// [HEALTH APP] — Food Search Service
// Orchestrates 3 tiers of food data, all running in parallel:
//   Tier 1 — USDA FoodData Central (generic foods, lab-measured)
//   Tier 2 — Indian foods JSON (offline, instant — indian_foods.json + indian_packaged_foods.json)
//   Tier 3 — Open Food Facts (packaged/international foods)
//
// Architecture:
//   • All 3 tiers run concurrently via Future.wait — no tier blocks another
//   • Each tier has independent error handling — one failure never blocks others
//   • Results sorted: Indian first → USDA → Open Food Facts
//   • In-memory LRU cache (NutritionCache) prevents redundant API calls
//   • 5-second timeout on every HTTP call

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_search_result.dart';
import '../../models/food_log_model.dart';
import '../nutrition/providers/usda_provider.dart';
import '../nutrition/providers/open_food_facts_provider.dart';

class FoodSearchService {
  FoodSearchService._();
  static final FoodSearchService instance = FoodSearchService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Provider singletons
  final USDAProvider _usda = USDAProvider.instance;
  final OpenFoodFactsProvider _off = OpenFoodFactsProvider.instance;

  // Cached Indian foods (loaded once from asset bundle)
  List<FoodSearchResult>? _indianFoodsCache;
  List<FoodSearchResult>? _indianPackagedCache;

  // ─────────────────────────────────────────────────────────────────────────────
  // Master search — all 3 tiers in parallel
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<FoodSearchResult>> search(String query, String userId) async {
    if (query.trim().length < 2) return [];

    debugPrint('[SEARCH] Query: "$query"');

    // Run all 3 tiers concurrently
    final futures = await Future.wait([
      _searchUSDA(query),
      _searchIndianLocal(query),
      _searchOpenFoodFacts(query),
    ]);

    final usda   = futures[0];
    final indian = futures[1];
    final off    = futures[2];

    // Merge with priority: Indian first → USDA → OFF
    final combined = <FoodSearchResult>[...indian, ...usda, ...off];

    // Deduplicate by normalized name
    final ranked = _deduplicate(combined);

    debugPrint('[SEARCH] Results: indian=${indian.length} usda=${usda.length} off=${off.length} total=${ranked.length.clamp(0, 20)}');
    return ranked.take(20).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tier 0 — Recent foods (last 8 distinct, by name)
  // ─────────────────────────────────────────────────────────────────────────────
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
    } catch (e) {
      debugPrint('[SEARCH] getRecentFoods error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tier 0 — Usual foods (top 5 by log frequency)
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<FoodLogModel>> getUsualFoods(
      String userId, {int limit = 5}) async {
    try {
      final data = await _client
          .from('food_logs')
          .select(
              'food_name, calories, protein_g, carbs_g, fat_g, fibre_g, quantity_g, food_source')
          .eq('user_id', userId);

      final counts  = <String, int>{};
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
        counts[model.foodName]  = (counts[model.foodName] ?? 0) + 1;
        samples[model.foodName] = model;
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((e) => samples[e.key]!).toList();
    } catch (e) {
      debugPrint('[SEARCH] getUsualFoods error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tier 1 — USDA FoodData Central
  // Endpoint: /fdc/v1/foods/search
  // dataType includes Foundation, SR Legacy, Survey FNDDS, Branded
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<FoodSearchResult>> _searchUSDA(String query) async {
    try {
      final results = await _usda.searchFoods(query);
      return results.map((f) => f.toFoodSearchResult()).toList();
    } catch (e) {
      debugPrint('[SEARCH] USDA tier error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tier 2 — Indian foods JSON (offline, instant)
  // Searches both indian_foods.json and indian_packaged_foods.json
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<FoodSearchResult>> _searchIndianLocal(String query) async {
    try {
      final q = query.toLowerCase();
      final generic  = await _loadIndianFoods();
      final packaged = await _loadIndianPackaged();

      final hits = <FoodSearchResult>[
        ...generic.where((f) => f.foodName.toLowerCase().contains(q)),
        ...packaged.where((f) => f.foodName.toLowerCase().contains(q)),
      ];

      return hits.take(6).toList();
    } catch (e) {
      debugPrint('[SEARCH] Indian local error: $e');
      return [];
    }
  }

  Future<List<FoodSearchResult>> _loadIndianFoods() async {
    if (_indianFoodsCache != null) return _indianFoodsCache!;
    try {
      final raw = await rootBundle.loadString('assets/indian_foods.json');
      final list = jsonDecode(raw) as List;
      _indianFoodsCache = list
          .map((e) => FoodSearchResult.fromJson(e, source: FoodSource.indianLocal))
          .toList();
      return _indianFoodsCache!;
    } catch (e) {
      debugPrint('[SEARCH] Failed to load indian_foods.json: $e');
      return [];
    }
  }

  Future<List<FoodSearchResult>> _loadIndianPackaged() async {
    if (_indianPackagedCache != null) return _indianPackagedCache!;
    try {
      final raw = await rootBundle.loadString('assets/indian_packaged_foods.json');
      final list = jsonDecode(raw) as List;
      _indianPackagedCache = list.map<FoodSearchResult>((e) {
        final p = e['per_100g'] as Map<String, dynamic>? ?? {};
        return FoodSearchResult(
          foodName:        e['name']     as String? ?? '',
          servingSizeG:   (e['serving_size_g'] as num?)?.toDouble() ?? 100,
          caloriesPer100g: _d(p['calories']),
          proteinPer100g:  _d(p['protein_g']),
          carbsPer100g:    _d(p['carbs_g']),
          fatPer100g:      _d(p['fat_g']),
          fibrePer100g:    _d(p['fibre_g']),
          brand:           e['brand']    as String?,
          barcode:         e['barcode']  as String?,
          source: FoodSource.indianLocal,
        );
      }).where((f) => f.foodName.isNotEmpty).toList();
      return _indianPackagedCache!;
    } catch (e) {
      debugPrint('[SEARCH] Failed to load indian_packaged_foods.json: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Tier 3 — Open Food Facts
  // ─────────────────────────────────────────────────────────────────────────────
  Future<List<FoodSearchResult>> _searchOpenFoodFacts(String query) async {
    try {
      final results = await _off.searchFoods(query);
      return results.map((f) => f.toFoodSearchResult()).toList();
    } catch (e) {
      debugPrint('[SEARCH] OFF tier error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Deduplicate by normalized food name (case-insensitive, whitespace-collapsed)
  // ─────────────────────────────────────────────────────────────────────────────
  List<FoodSearchResult> _deduplicate(List<FoodSearchResult> items) {
    final seen = <String>{};
    return items.where((item) {
      final key = item.foodName
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return seen.add(key);
    }).toList();
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    return (v as num).toDouble();
  }
}
