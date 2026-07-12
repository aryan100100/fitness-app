// [HEALTH APP] — USDA FoodData Central Provider
// Implements NutritionProvider for the USDA FoodData Central REST API.
//
// Endpoints used:
//   Search:  GET /fdc/v1/foods/search
//   Detail:  GET /fdc/v1/food/{fdcId}
//
// Features:
//   • Reads 7 nutrient IDs: energy, protein, carbs, fat, fibre, sugar, sodium
//   • 3-attempt retry with exponential backoff on 429/5xx
//   • 8-second per-attempt timeout
//   • In-memory LRU cache via NutritionCache
//   • Input validation (min 2 chars, trimmed)
//   • Structured logging under [USDA] prefix
//   • Returns empty list / null on any error — never throws

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../nutrition_provider.dart';
import '../nutrition_cache.dart';
import '../unified_food.dart';

class USDAProvider implements NutritionProvider {
  USDAProvider._();
  static final USDAProvider instance = USDAProvider._();

  @override
  String get providerId => 'usda';

  @override
  String get displayName => 'USDA FoodData Central';

  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxRetries = 3;
  static const int _pageSize = 15;

  // USDA nutrient IDs  ─────────────────────────────────────────────────────────
  static const int _idEnergy  = 1008;
  static const int _idProtein = 1003;
  static const int _idCarbs   = 1005;
  static const int _idFat     = 1004;
  static const int _idFibre   = 1079;
  static const int _idSugar   = 2000;
  static const int _idSodium  = 1093;

  String get _apiKey => dotenv.env['USDA_API_KEY']?.trim() ?? '';

  final NutritionCache _cache = NutritionCache.instance;

  // ── Search ────────────────────────────────────────────────────────────────────

  @override
  Future<List<UnifiedFood>> searchFoods(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    // Cache check
    final cached = _cache.getSearch('usda:$q');
    if (cached != null) {
      debugPrint('[USDA] Cache HIT: "$q"');
      return cached;
    }

    if (_apiKey.isEmpty) {
      debugPrint('[USDA] ⚠️ USDA_API_KEY not set — skipping USDA search');
      return [];
    }

    final uri = Uri.parse(
      '$_baseUrl/foods/search'
      '?query=${Uri.encodeComponent(q)}'
      '&api_key=$_apiKey'
      '&dataType=Foundation,SR%20Legacy,Survey%20%28FNDDS%29'
      '&pageSize=$_pageSize',
    );

    try {
      final body = await _getWithRetry(uri);
      if (body == null) return [];

      final json = jsonDecode(body) as Map<String, dynamic>;
      final foods = json['foods'] as List? ?? [];

      final results = foods
          .map((f) => _parseFoodItem(f as Map<String, dynamic>))
          .whereType<UnifiedFood>()
          .toList();

      debugPrint('[USDA] Search "$q" → ${results.length} results');
      _cache.putSearch('usda:$q', results);
      return results;
    } catch (e) {
      debugPrint('[USDA] searchFoods error: $e');
      return [];
    }
  }

  // ── Barcode ───────────────────────────────────────────────────────────────────
  // USDA does not have barcode lookup — returns null always.

  @override
  Future<UnifiedFood?> lookupBarcode(String barcode) async => null;

  // ── Food details by fdcId ──────────────────────────────────────────────────────

  @override
  Future<UnifiedFood?> getFoodDetails(String providerFoodId) async {
    final cacheKey = 'usda:detail:$providerFoodId';
    final cached = _cache.getSearch(cacheKey);
    if (cached != null && cached.isNotEmpty) return cached.first;

    if (_apiKey.isEmpty) return null;

    final uri = Uri.parse('$_baseUrl/food/$providerFoodId?api_key=$_apiKey');

    try {
      final body = await _getWithRetry(uri);
      if (body == null) return null;

      final json = jsonDecode(body) as Map<String, dynamic>;
      final food = _parseFoodDetail(json);
      if (food != null) {
        _cache.putSearch(cacheKey, [food]);
      }
      return food;
    } catch (e) {
      debugPrint('[USDA] getFoodDetails($providerFoodId) error: $e');
      return null;
    }
  }

  // ── Parsers ───────────────────────────────────────────────────────────────────

  /// Parses a food item from the /foods/search response.
  UnifiedFood? _parseFoodItem(Map<String, dynamic> f) {
    try {
      final name = (f['description'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      final fdcId = f['fdcId']?.toString();
      final nutrients = f['foodNutrients'] as List? ?? [];
      final macros = _extractMacros(nutrients);

      if (macros['calories']! <= 0) return null;

      return UnifiedFood(
        foodName: name,
        providerId: providerId,
        providerFoodId: fdcId,
        caloriesPer100g: macros['calories']!,
        proteinPer100g: macros['protein']!,
        carbsPer100g: macros['carbs']!,
        fatPer100g: macros['fat']!,
        fibrePer100g: macros['fibre']!,
        sugarPer100g: macros['sugar']!,
        sodiumPer100g: macros['sodium']!,
        defaultServingG: 100,
        confidence: NutritionConfidence.high, // USDA is lab-measured
      );
    } catch (e) {
      debugPrint('[USDA] _parseFoodItem error: $e');
      return null;
    }
  }

  /// Parses a food item from the /food/{fdcId} detail response.
  UnifiedFood? _parseFoodDetail(Map<String, dynamic> f) {
    try {
      final name = (f['description'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      final fdcId = f['fdcId']?.toString();

      // Detail endpoint uses a different nutrient array structure
      final nutrients = f['foodNutrients'] as List? ?? [];
      final macroMap = <int, double>{};
      for (final n in nutrients) {
        final nutrient = n['nutrient'] as Map<String, dynamic>? ?? {};
        final id = nutrient['id'] as int? ?? 0;
        final amount = (n['amount'] as num?)?.toDouble() ?? 0;
        macroMap[id] = amount;
      }

      final macros = _macrosFromMap(macroMap);
      if (macros['calories']! <= 0) return null;

      // Try to get a default serving from foodPortions
      double servingG = 100;
      final portions = f['foodPortions'] as List?;
      if (portions != null && portions.isNotEmpty) {
        final first = portions.first as Map<String, dynamic>;
        servingG = (first['gramWeight'] as num?)?.toDouble() ?? 100;
      }

      return UnifiedFood(
        foodName: name,
        providerId: providerId,
        providerFoodId: fdcId,
        caloriesPer100g: macros['calories']!,
        proteinPer100g: macros['protein']!,
        carbsPer100g: macros['carbs']!,
        fatPer100g: macros['fat']!,
        fibrePer100g: macros['fibre']!,
        sugarPer100g: macros['sugar']!,
        sodiumPer100g: macros['sodium']!,
        defaultServingG: servingG,
        confidence: NutritionConfidence.high,
      );
    } catch (e) {
      debugPrint('[USDA] _parseFoodDetail error: $e');
      return null;
    }
  }

  /// Extracts macros from the search-result nutrient list (uses `nutrientId`).
  Map<String, double> _extractMacros(List nutrients) {
    final map = <int, double>{};
    for (final n in nutrients) {
      final idVal = n['nutrientId'] as int? ?? 0;
      final val = (n['value'] as num?)?.toDouble() ?? 0;
      map[idVal] = val;
    }
    return _macrosFromMap(map);
  }

  Map<String, double> _macrosFromMap(Map<int, double> map) => {
        'calories': map[_idEnergy] ?? 0,
        'protein': map[_idProtein] ?? 0,
        'carbs': map[_idCarbs] ?? 0,
        'fat': map[_idFat] ?? 0,
        'fibre': map[_idFibre] ?? 0,
        'sugar': map[_idSugar] ?? 0,
        'sodium': map[_idSodium] ?? 0,
      };

  // ── HTTP with retry ───────────────────────────────────────────────────────────

  /// GET [uri] with up to [_maxRetries] attempts, exponential backoff.
  /// Returns response body string on success, null on final failure.
  Future<String?> _getWithRetry(Uri uri) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode == 200) return response.body;

        if (response.statusCode == 429 || response.statusCode >= 500) {
          // Retryable — wait before next attempt
          final waitMs = 1000 * (1 << (attempt - 1)); // 1s, 2s, 4s
          debugPrint(
              '[USDA] HTTP ${response.statusCode} on attempt $attempt — retrying in ${waitMs}ms');
          await Future.delayed(Duration(milliseconds: waitMs));
          continue;
        }

        // Non-retryable (400, 403, 404)
        debugPrint('[USDA] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return null;
      } on TimeoutException {
        debugPrint('[USDA] Timeout on attempt $attempt');
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
        }
      } catch (e) {
        debugPrint('[USDA] Request error on attempt $attempt: $e');
        return null;
      }
    }
    debugPrint('[USDA] All $maxRetries attempts exhausted');
    return null;
  }

  // ignore: non_constant_identifier_names — intentional const-like name
  static int get maxRetries => _maxRetries;
}
