// [HEALTH APP] — Barcode Service (Feature 10)
// 4-tier product lookup: user_saved → OFF → Indian DB → Nutritionix
// All HTTP calls have 5-second timeout. No barcode data sent for on-device decode.
// Scanning is on-device via mobile_scanner (ML Kit).

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/barcode_product_model.dart';

class BarcodeService {
  BarcodeService._();
  static final BarcodeService instance = BarcodeService._();

  SupabaseClient get _client => Supabase.instance.client;
  static const _timeout = Duration(seconds: 5);

  // Cached Indian DB (loaded once from asset)
  List<dynamic>? _indianDbCache;

  // ───────────────────────────────────────────────────────────────────────────
  // MAIN ENTRY — tries tiers in order, returns first hit
  // ───────────────────────────────────────────────────────────────────────────
  Future<BarcodeResult> lookupBarcode(String barcode,
      {required String userId}) async {
    // Tier 0 — user's personal saved foods (instant, highest priority)
    final saved = await _lookupUserSaved(userId, barcode);
    if (saved != null) {
      return BarcodeResult(
          product: saved, found: true, source: 'user_saved', confidence: saved.confidence);
    }

    // Tier 1 — Open Food Facts (primary)
    final offProduct = await _lookupOpenFoodFacts(barcode);
    if (offProduct != null) {
      return BarcodeResult(
          product: offProduct,
          found: true,
          source: 'off',
          confidence: offProduct.confidence);
    }

    // Tier 2.5 — Indian packaged foods JSON (offline, high accuracy)
    final indianProduct = await _lookupIndianDatabase(barcode);
    if (indianProduct != null) {
      return BarcodeResult(
          product: indianProduct,
          found: true,
          source: 'indian_db',
          confidence: ConfidenceLevel.high);
    }

    // Tier 3 — Nutritionix UPC
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

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 0 — user's custom_foods table (with barcode column)
  // ───────────────────────────────────────────────────────────────────────────
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

      if (rows == null || (rows as List).isEmpty) return null;
      return BarcodeProduct.fromCustomFood(rows[0] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 1 — Open Food Facts API v2
  // ───────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupOpenFoodFacts(String barcode) async {
    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final res =
          await http.get(uri, headers: {'User-Agent': 'HealthApp/1.0'}).timeout(_timeout);

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null; // product not found

      final product = body['product'] as Map<String, dynamic>? ?? {};
      final name = (product['product_name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      final confidence = _assessConfidence(product);
      // Merge the barcode into the product map and construct from it
      final productWithCode = Map<String, dynamic>.from(product)
        ..['code'] = barcode;
      return BarcodeProduct.fromOff(productWithCode, confidence);
    } catch (e) {
      return null;
    }
  }

  /// Assess confidence from OFF response fields.
  ConfidenceLevel _assessConfidence(Map<String, dynamic> p) {
    final score =
        (p['completeness'] as num? ?? (p['completeness_score'] as num? ?? 0))
            .toInt();
    final n = p['nutriments'] as Map<String, dynamic>? ?? {};
    final hasMacros = n.containsKey('proteins_100g') &&
        n.containsKey('carbohydrates_100g') &&
        n.containsKey('fat_100g') &&
        n.containsKey('energy-kcal_100g');

    if (score >= 75 && hasMacros) return ConfidenceLevel.high;
    if (score >= 40 || n.isNotEmpty) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 2.5 — Indian packaged foods offline JSON
  // ───────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupIndianDatabase(String barcode) async {
    try {
      _indianDbCache ??= jsonDecode(
        await rootBundle.loadString('assets/indian_packaged_foods.json'),
      ) as List<dynamic>;

      final match = _indianDbCache!.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['barcode'] == barcode,
        orElse: () => <String, dynamic>{},
      );

      if (match.isEmpty) return null;
      return BarcodeProduct.fromIndianDb(match as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 3 — Nutritionix UPC lookup (secondary, paid API)
  // ───────────────────────────────────────────────────────────────────────────
  Future<BarcodeProduct?> _lookupNutritionix(String barcode) async {
    try {
      final appId = dotenv.maybeGet('NUTRITIONIX_APP_ID') ?? '';
      final appKey = dotenv.maybeGet('NUTRITIONIX_API_KEY') ?? '';
      if (appId.isEmpty || appKey.isEmpty) return null;

      final uri = Uri.parse(
          'https://trackapi.nutritionix.com/v2/search/item?upc=$barcode');
      final res = await http.get(uri, headers: {
        'x-app-id': appId,
        'x-app-key': appKey,
        'x-remote-user-id': '0',
      }).timeout(_timeout);

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final foods = body['foods'] as List?;
      if (foods == null || foods.isEmpty) return null;

      return BarcodeProduct.fromNutritionix(foods[0] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Save a user-submitted product to custom_foods with the barcode
  // ───────────────────────────────────────────────────────────────────────────
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
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Log a successful scan for analytics (fire-and-forget)
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> logScan(
      String userId, String barcode, String source) async {
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
