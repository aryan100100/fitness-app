// [HEALTH APP] — Open Food Facts Provider
// Implements NutritionProvider for the Open Food Facts API (free, no key needed).
//
// Endpoints used:
//   Barcode: GET https://world.openfoodfacts.org/api/v2/product/{barcode}.json
//   Search:  GET https://world.openfoodfacts.org/cgi/search.pl
//
// Features:
//   • Barcode lookup (primary use case for OFF)
//   • Text search with 10 results, including brand + imageUrl + barcode
//   • Dual fibre key fallback: fiber_100g → fibers_100g
//   • Energy fallback: energy-kcal_100g → energy_100g ÷ 4.184
//   • Confidence assessment (high/medium/low) from completeness score
//   • 2-attempt retry, 6-second timeout
//   • User-Agent set as required by OFF fair-use policy
//   • In-memory LRU cache via NutritionCache
//   • Returns empty list / null on any error — never throws

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../nutrition_provider.dart';
import '../nutrition_cache.dart';
import '../unified_food.dart';

class OpenFoodFactsProvider implements NutritionProvider {
  OpenFoodFactsProvider._();
  static final OpenFoodFactsProvider instance = OpenFoodFactsProvider._();

  @override
  String get providerId => 'openfoodfacts';

  @override
  String get displayName => 'Open Food Facts';

  static const String _baseUrl = 'https://world.openfoodfacts.org';
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxRetries = 2;
  static const int _pageSize = 10;

  // OFF requires a sensible User-Agent per their fair-use policy
  static const Map<String, String> _headers = {
    'User-Agent': 'NutriTrack/1.0 (contact@nutritrack.dev)',
  };

  final NutritionCache _cache = NutritionCache.instance;

  // ── Barcode lookup ────────────────────────────────────────────────────────────

  @override
  Future<UnifiedFood?> lookupBarcode(String barcode) async {
    // Cache check — hasBarcode distinguishes "cached null" from "not cached"
    if (_cache.hasBarcode('off:$barcode')) {
      final cached = _cache.getBarcode('off:$barcode');
      debugPrint('[OFF] Barcode cache HIT: $barcode → ${cached?.foodName ?? "not found"}');
      return cached;
    }

    final uri = Uri.parse('$_baseUrl/api/v2/product/$barcode.json');

    try {
      final body = await _getWithRetry(uri);
      if (body == null) {
        _cache.putBarcode('off:$barcode', null);
        return null;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] != 1) {
        debugPrint('[OFF] Barcode $barcode not found in OFF');
        _cache.putBarcode('off:$barcode', null);
        return null;
      }

      final product = json['product'] as Map<String, dynamic>? ?? {};
      final food = _parseProduct(product, barcode: barcode);

      _cache.putBarcode('off:$barcode', food);
      return food;
    } catch (e) {
      debugPrint('[OFF] lookupBarcode($barcode) error: $e');
      return null;
    }
  }

  // ── Text search ───────────────────────────────────────────────────────────────

  @override
  Future<List<UnifiedFood>> searchFoods(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final cached = _cache.getSearch('off:$q');
    if (cached != null) {
      debugPrint('[OFF] Search cache HIT: "$q"');
      return cached;
    }

    final uri = Uri.parse(
      '$_baseUrl/cgi/search.pl'
      '?search_terms=${Uri.encodeComponent(q)}'
      '&json=1'
      '&page_size=$_pageSize'
      '&fields=product_name,nutriments,brands,image_front_url,code,serving_quantity,completeness',
    );

    try {
      final body = await _getWithRetry(uri);
      if (body == null) return [];

      final json = jsonDecode(body) as Map<String, dynamic>;
      final products = json['products'] as List? ?? [];

      final results = products
          .map((p) => _parseProduct(p as Map<String, dynamic>))
          .whereType<UnifiedFood>()
          .toList();

      debugPrint('[OFF] Search "$q" → ${results.length} results');
      _cache.putSearch('off:$q', results);
      return results;
    } catch (e) {
      debugPrint('[OFF] searchFoods error: $e');
      return [];
    }
  }

  // ── USDA doesn't handle barcode but OFF detail IS the barcode lookup ──────────

  @override
  Future<UnifiedFood?> getFoodDetails(String providerFoodId) async {
    // For OFF, the provider food ID IS the barcode
    return lookupBarcode(providerFoodId);
  }

  // ── Parser ────────────────────────────────────────────────────────────────────

  UnifiedFood? _parseProduct(Map<String, dynamic> p, {String? barcode}) {
    try {
      final name = (p['product_name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      final n = p['nutriments'] as Map<String, dynamic>? ?? {};

      // Energy: prefer kcal key, fall back to kJ÷4.184
      double calories = _d(n['energy-kcal_100g']);
      if (calories == 0) {
        final kj = _d(n['energy_100g']);
        if (kj > 0) calories = kj / 4.184;
      }

      if (calories == 0) return null; // No usable calorie data

      // Fibre: OFF uses inconsistent key spelling
      double fibre = _d(n['fiber_100g']);
      if (fibre == 0) fibre = _d(n['fibers_100g']);

      final confidence = _assessConfidence(p);
      final bc = barcode ?? p['code'] as String?;

      return UnifiedFood(
        foodName: name,
        providerId: providerId,
        providerFoodId: bc,
        brand: p['brands'] as String?,
        barcode: bc,
        imageUrl: p['image_front_url'] as String?,
        caloriesPer100g: calories,
        proteinPer100g: _d(n['proteins_100g']),
        carbsPer100g: _d(n['carbohydrates_100g']),
        fatPer100g: _d(n['fat_100g']),
        fibrePer100g: fibre,
        sugarPer100g: _d(n['sugars_100g']),
        sodiumPer100g: _d(n['sodium_100g']) * 1000, // OFF stores g, we want mg
        defaultServingG: _d(p['serving_quantity'], fallback: 100),
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('[OFF] _parseProduct error: $e');
      return null;
    }
  }

  /// Confidence assessment from OFF completeness score and macro presence.
  NutritionConfidence _assessConfidence(Map<String, dynamic> p) {
    final score = (p['completeness'] as num? ??
            (p['completeness_score'] as num? ?? 0))
        .toInt();
    final n = p['nutriments'] as Map<String, dynamic>? ?? {};
    final hasMacros = n.containsKey('proteins_100g') &&
        n.containsKey('carbohydrates_100g') &&
        n.containsKey('fat_100g') &&
        (n.containsKey('energy-kcal_100g') || n.containsKey('energy_100g'));

    if (score >= 75 && hasMacros) return NutritionConfidence.high;
    if (score >= 40 || n.isNotEmpty) return NutritionConfidence.medium;
    return NutritionConfidence.low;
  }

  // ── HTTP with retry ───────────────────────────────────────────────────────────

  Future<String?> _getWithRetry(Uri uri) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response =
            await http.get(uri, headers: _headers).timeout(_timeout);

        if (response.statusCode == 200) return response.body;

        if (response.statusCode == 429 || response.statusCode >= 500) {
          final waitMs = 1500 * attempt;
          debugPrint(
              '[OFF] HTTP ${response.statusCode} on attempt $attempt — retrying in ${waitMs}ms');
          await Future.delayed(Duration(milliseconds: waitMs));
          continue;
        }

        debugPrint('[OFF] HTTP ${response.statusCode} — not retrying');
        return null;
      } on TimeoutException {
        debugPrint('[OFF] Timeout on attempt $attempt');
        // Always retry on timeout up to max
      } catch (e) {
        debugPrint('[OFF] Request error on attempt $attempt: $e');
        return null;
      }
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static double _d(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    return (v as num).toDouble();
  }
}
