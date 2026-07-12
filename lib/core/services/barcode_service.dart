// [HEALTH APP] — Barcode Service (Feature 10)
// 4-tier product lookup: user_saved → OFF → Indian DB → Nutritionix
// Tier 1 (OFF) now delegates to OpenFoodFactsProvider for consistency,
// caching, retry logic, and confidence assessment.
// All HTTP calls have 5-second timeout. Scanning is on-device via mobile_scanner.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/barcode_product_model.dart';
import '../nutrition/providers/open_food_facts_provider.dart';
import '../nutrition/unified_food.dart';

class BarcodeService {
  BarcodeService._();
  static final BarcodeService instance = BarcodeService._();

  SupabaseClient get _client => Supabase.instance.client;
  static const _timeout = Duration(seconds: 5);

  // Cached Indian DB (loaded once from asset)
  List<dynamic>? _indianDbCache;

  // OFF provider (handles caching + retries internally)
  final OpenFoodFactsProvider _off = OpenFoodFactsProvider.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // MAIN ENTRY — tries tiers in order, returns first hit
  // ────────────────────────────────────────────────────────────────────────────
  Future<BarcodeResult> lookupBarcode(String barcode,
      {required String userId}) async {
    // Tier 0 — user's personal saved foods (instant, highest priority)
    final saved = await _lookupUserSaved(userId, barcode);
    if (saved != null) {
      return BarcodeResult(
          product: saved,
          found: true,
          source: 'user_saved',
          confidence: saved.confidence);
    }

    // Tier 1 — Open Food Facts (via OFFProvider — cached + retried)
    final offProduct = await _lookupOpenFoodFacts(barcode);
    if (offProduct != null) {
      return BarcodeResult(
          product: offProduct,
          found: true,
          source: 'off',
          confidence: offProduct.confidence);
    }

    // Tier 2 — Indian packaged foods JSON (offline, high accuracy)
    final indianProduct = await _lookupIndianDatabase(barcode);
    if (indianProduct != null) {
      return BarcodeResult(
          product: indianProduct,
          found: true,
          source: 'indian_db',
          confidence: ConfidenceLevel.high);
    }

    // Tier 3 — Nutritionix UPC (requires API keys)
    final nixProduct = await _lookupNutritionix(barcode);
    if (nixProduct != null) {
      return BarcodeResult(
          product: nixProduct,
          found: true,
          source: 'nutritionix',
          confidence: nixProduct.confidence);
    }

    // Tier 4 — Not found
    return BarcodeResult.notFound();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tier 0 — user's custom_foods table (with barcode column)
  // ────────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupUserSaved(
      String userId, String barcode) async {
    try {
      final rows = await _client
          .from('custom_foods')
          .select(
              'name, barcode, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fibre_per_100g, serving_size_g')
          .eq('user_id', userId)
          .eq('barcode', barcode)
          .limit(1);

      if (rows.isEmpty) return null;
      return BarcodeProduct.fromCustomFood(rows.first);
    } catch (e) {
      debugPrint('[BARCODE] User-saved lookup error: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tier 1 — Open Food Facts (via OFFProvider — caching + retry handled there)
  // ────────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupOpenFoodFacts(String barcode) async {
    try {
      final UnifiedFood? food = await _off.lookupBarcode(barcode);
      if (food == null) return null;

      final confidence = switch (food.confidence) {
        NutritionConfidence.high   => ConfidenceLevel.high,
        NutritionConfidence.medium => ConfidenceLevel.medium,
        NutritionConfidence.low    => ConfidenceLevel.low,
      };

      return BarcodeProduct(
        barcode:        food.barcode,
        name:           food.foodName,
        brand:          food.brand,
        imageUrl:       food.imageUrl,
        caloriesPer100g: food.caloriesPer100g,
        proteinPer100g:  food.proteinPer100g,
        carbsPer100g:    food.carbsPer100g,
        fatPer100g:      food.fatPer100g,
        fibrePer100g:    food.fibrePer100g,
        servingSizeG:    food.defaultServingG,
        source:          'off',
        confidence:      confidence,
      );
    } catch (e) {
      debugPrint('[BARCODE] OFF lookup error: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tier 2 — Indian packaged foods offline JSON
  // ────────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupIndianDatabase(String barcode) async {
    try {
      _indianDbCache ??= jsonDecode(
        await rootBundle.loadString('assets/indian_packaged_foods.json'),
      ) as List<dynamic>;

      final match = _indianDbCache!
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (e) => e['barcode'] == barcode,
            orElse: () => <String, dynamic>{},
          );

      if (match.isEmpty) return null;
      return BarcodeProduct.fromIndianDb(match);
    } catch (e) {
      debugPrint('[BARCODE] Indian DB lookup error: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Tier 3 — Nutritionix UPC lookup (secondary, paid API)
  // ────────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupNutritionix(String barcode) async {
    try {
      final appId  = dotenv.maybeGet('NUTRITIONIX_APP_ID') ?? '';
      final appKey = dotenv.maybeGet('NUTRITIONIX_API_KEY') ?? '';
      if (appId.isEmpty || appKey.isEmpty) return null;

      final uri = Uri.parse(
          'https://trackapi.nutritionix.com/v2/search/item?upc=$barcode');
      final res = await http.get(uri, headers: {
        'x-app-id': appId,
        'x-app-key': appKey,
        'x-remote-user-id': '0',
      }).timeout(_timeout);

      if (res.statusCode != 200) {
        debugPrint('[BARCODE] Nutritionix HTTP ${res.statusCode}');
        return null;
      }

      final body  = jsonDecode(res.body) as Map<String, dynamic>;
      final foods = body['foods'] as List?;
      if (foods == null || foods.isEmpty) return null;

      return BarcodeProduct.fromNutritionix(foods[0] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[BARCODE] Nutritionix lookup error: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Save a user-submitted product to custom_foods with the barcode
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> saveUserProduct(String userId, BarcodeProduct product,
      {String? productName}) async {
    try {
      await _client.from('custom_foods').upsert({
        'user_id': userId,
        'name': productName ?? product.name,
        'barcode': product.barcode,
        'calories_per_100g': product.caloriesPer100g,
        'protein_per_100g': product.proteinPer100g,
        'carbs_per_100g': product.carbsPer100g,
        'fat_per_100g': product.fatPer100g,
        'fibre_per_100g': product.fibrePer100g ?? 0.0,
        'serving_size_g': product.servingSizeG,
        'source': 'barcode_scan',
      });
    } catch (e) {
      debugPrint('[BARCODE] saveUserProduct error: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Log a successful scan for analytics (fire-and-forget)
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> logScan(String userId, String barcode, String source) async {
    try {
      await _client.from('barcode_scan_logs').insert({
        'user_id': userId,
        'barcode': barcode,
        'source': source,
        'scanned_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Non-critical — never throw
    }
  }
}
