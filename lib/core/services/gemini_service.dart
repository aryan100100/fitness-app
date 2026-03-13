// [HEALTH APP] — Gemini AI Service
// Uses direct HTTP calls to the Gemini v1 REST API.
// The google_generative_ai Flutter package hardcodes a v1beta endpoint
// internally which does not support flash models — bypassed permanently here.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/meal_plan_result.dart';
import '../../models/recipe_result.dart';
import '../../models/user_model.dart';

// ---------------------------------------------------------------------------
// Custom exception
// ---------------------------------------------------------------------------
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => 'GeminiException: $message';
}

// ---------------------------------------------------------------------------
// GeminiService — singleton
// ---------------------------------------------------------------------------
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  // ── v1 REST endpoint — gemini-2.5-flash confirmed working on this API key ──
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // ---------------------------------------------------------------------------
  // Internal: strip markdown fences from response text (safety fallback).
  // ---------------------------------------------------------------------------
  String _cleanJson(String raw) {
    String s = raw.trim();
    if (s.startsWith('```json') || s.startsWith('```JSON')) {
      s = s.substring(7);
    } else if (s.startsWith('```')) {
      s = s.substring(3);
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  // ---------------------------------------------------------------------------
  // Core HTTP helper — sends a text prompt, returns parsed JSON.
  // Verbose diagnostic logging. Never silently swallows errors.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _sendJsonPrompt(String prompt) async {
    final apiKey = _apiKey;

    if (kDebugMode) {
      debugPrint('[GEMINI] === REQUEST START ===');
      debugPrint('[GEMINI] URL: $_baseUrl');
      if (apiKey.isEmpty) {
        debugPrint('[GEMINI] ⚠️  Key is EMPTY — add GEMINI_API_KEY to .env');
      } else {
        debugPrint(
            '[GEMINI] Key prefix: ${apiKey.substring(0, apiKey.length >= 8 ? 8 : apiKey.length)}...'
            ' (${apiKey.length} chars total)');
      }
      debugPrint('[GEMINI] Prompt length: ${prompt.length} chars');
    }

    final uri = Uri.parse('$_baseUrl?key=$apiKey');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 8192,
      }
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[GEMINI] HTTP status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[GEMINI] ❌ HTTP error body: ${response.body}');
        throw GeminiException('HTTP ${response.statusCode}: ${response.body}');
      }

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;

      final text = (responseJson['candidates'] as List?)
          ?.firstOrNull?['content']?['parts']?[0]?['text'] as String?;

      if (text == null || text.isEmpty) {
        debugPrint('[GEMINI] ❌ No text in response: ${response.body}');
        throw GeminiException('No content in Gemini response');
      }

      debugPrint(
          '[GEMINI] Raw response (first 300 chars): '
          '${text.substring(0, text.length.clamp(0, 300))}');

      // ── Step 1: clean fences then direct parse ──────────────────────────
      final cleaned = _cleanJson(text);
      try {
        final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
        if (parsed.containsKey('error')) {
          debugPrint('[GEMINI] API returned error object: ${parsed['error']}');
          throw GeminiException('Gemini error: ${parsed['error']}');
        }
        debugPrint('[GEMINI] ✅ JSON parsed OK');
        return parsed;
      } catch (parseErr) {
        if (parseErr is GeminiException) rethrow;
        debugPrint('[GEMINI] Direct parse unsuccessful: $parseErr');
      }

      // ── Step 2: regex fallback ──────────────────────────────────────────
      final match = RegExp(r'\{[\s\S]*\}', multiLine: true).firstMatch(text);
      if (match != null) {
        debugPrint('[GEMINI] Trying regex fallback…');
        try {
          final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
          debugPrint('[GEMINI] ✅ Fallback parse OK');
          return parsed;
        } catch (_) {
          debugPrint('[GEMINI] Fallback parse also unsuccessful');
        }
      }

      throw GeminiException('All JSON parse attempts exhausted. Raw: $text');

    } on TimeoutException {
      debugPrint('[GEMINI] ❌ Timed out after 30 seconds');
      throw GeminiException('Request timed out — check your internet connection');
    } catch (e, stack) {
      if (e is GeminiException) rethrow;
      debugPrint('[GEMINI] ❌ Exception: ${e.runtimeType}');
      debugPrint('[GEMINI] Message: $e');
      if (kDebugMode) debugPrint('[GEMINI] Stack:\n$stack');
      throw GeminiException(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 5 — Diet Planner: Generate a full-day meal plan.
  // ---------------------------------------------------------------------------
  Future<MealPlanResult?> generateMealPlan(
    UserModel user,
    List<String> availableFoods,
  ) async {
    final today = _todayString();
    final foodsLine = availableFoods.isNotEmpty
        ? availableFoods.join(', ')
        : 'No specific foods — use best judgement for their situation';
    final prefsLine = user.foodPreferences.isNotEmpty
        ? user.foodPreferences.join(', ')
        : 'None specified';
    final goalLabel = user.goal == 'lose'
        ? 'achieving their health goals'
        : user.goal == 'gain'
            ? 'building muscle and healthy weight gain'
            : 'maintaining a healthy weight';

    final prompt = '''
You are an expert nutritionist. Generate a complete one-day meal plan.
User profile:
- Life situation: ${user.lifeSituation}
- Region: ${user.region}
- Daily calorie target: ${user.targetCalories.toInt()} kcal
- Protein target: ${user.proteinG.toInt()}g
- Carbohydrates target: ${user.carbsG.toInt()}g
- Fat target: ${user.fatG.toInt()}g
- Fibre target: ${user.fiberG.toInt()}g
- Goal: $goalLabel
- Available foods today: $foodsLine
- Food preferences: $prefsLine

Rules:
- Build the plan primarily around available foods if listed.
- For hostel_student: no-cook or minimal prep. Student budget.
- For office_worker: packable, quick-prep or nearby food options.
- For work_from_home or homemaker: home-cooked meals.
- Hit calorie and protein targets within 5%.
- Exactly 4 meals: breakfast, lunch, dinner, snack.

Respond with ONLY a raw JSON object matching this schema exactly:
{"planDate":"$today","totalCalories":0,"totalProtein":0,"totalCarbs":0,"totalFat":0,"totalFibre":0,"meals":[{"mealType":"breakfast","mealName":"string","items":[{"name":"string","quantity":"string","calories":0,"protein":0,"carbs":0,"fat":0,"fibre":0}],"totalCalories":0,"totalProtein":0,"totalCarbs":0,"totalFat":0,"totalFibre":0,"prepNote":"string"}]}''';

    try {
      final raw = await _sendJsonPrompt(prompt);
      return MealPlanResult.fromJson(raw);
    } catch (e) {
      debugPrint('[GEMINI] generateMealPlan error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 5 — Recipe Generator with optional macro-fit toggle.
  // ---------------------------------------------------------------------------
  Future<RecipeResult?> generateRecipeResult({
    required String query,
    required UserModel user,
    bool fitMacros = false,
    double? remCalories,
    double? remProtein,
    double? remCarbs,
    double? remFat,
  }) async {
    final macroLine = fitMacros && remCalories != null
        ? 'Adjust recipe quantities to fit remaining macros: '
            '${remCalories.toInt()} kcal, ${remProtein!.toInt()}g protein, '
            '${remCarbs!.toInt()}g carbs, ${remFat!.toInt()}g fat.'
        : '';

    final prompt = '''
Generate a detailed recipe for: $query.
User region: ${user.region}. Life situation: ${user.lifeSituation}.
$macroLine

Respond with ONLY a raw JSON object matching this schema:
{"recipeName":"string","servings":1,"prepTimeMinutes":0,"cookTimeMinutes":0,"ingredients":[{"name":"string","quantity":"string","gramsEquivalent":0}],"instructions":["string"],"nutritionPerServing":{"calories":0,"protein":0,"carbs":0,"fat":0,"fibre":0},"macroNote":"string"}''';

    try {
      final raw = await _sendJsonPrompt(prompt);
      return RecipeResult.fromJson(raw);
    } catch (e) {
      debugPrint('[GEMINI] generateRecipeResult error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 4 — Photo Calorie Estimator (Vision) — also via direct HTTP.
  // ---------------------------------------------------------------------------
  Future<PhotoEstimateResult> estimateMealFromPhoto(
      List<int> imageBytes, String mimeType) async {
    const visionPrompt =
        'You are a nutrition expert analyzing a photo of food. '
        'Provide your best estimate of nutritional content. '
        'Consider typical portion sizes. '
        'Respond with ONLY a raw JSON object: '
        '{"foods":["item1"],"totalCalories":0,"protein":0,"carbs":0,"fat":0,"fibre":0,'
        '"confidence":"medium","portionNotes":"string","warningMessage":"string or null"}';

    final apiKey = _apiKey;
    final uri = Uri.parse('$_baseUrl?key=$apiKey');
    final base64Image = base64Encode(Uint8List.fromList(imageBytes));

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            },
            {'text': visionPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 1024,
      }
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw PhotoEstimationException(
            'HTTP ${response.statusCode}: ${response.body}');
      }

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;
      final text = (responseJson['candidates'] as List?)
          ?.firstOrNull?['content']?['parts']?[0]?['text'] as String?;

      if (text == null || text.isEmpty) {
        throw PhotoEstimationException('Empty response from Gemini');
      }

      final cleaned = _cleanJson(text);
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return PhotoEstimateResult.fromJson(json);
    } on PhotoEstimationException {
      rethrow;
    } catch (e) {
      throw PhotoEstimationException('Could not analyze photo: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 7 — Emergency Button: Encouraging message (plain text, not JSON).
  // ---------------------------------------------------------------------------
  Future<String?> generateEmergencyMessage({
    required int caloriesOver,
    required String adjustmentType,
  }) async {
    final actionDesc = adjustmentType == 'distribute_week'
        ? 'they will distribute the extra $caloriesOver calories across the rest of the week'
        : 'they will push their goal date back by a few days';

    final prompt =
        'A user tracking their diet went over their calorie target by '
        '$caloriesOver calories. They chose to handle it by: $actionDesc. '
        'Write a short, warm, non-judgmental encouraging message (2-3 sentences). '
        'Respond with only the plain text message, no JSON, no formatting.';

    final apiKey = _apiKey;
    final uri = Uri.parse('$_baseUrl?key=$apiKey');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.8,
        'maxOutputTokens': 256,
      }
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;
      return (responseJson['candidates'] as List?)
          ?.firstOrNull?['content']?['parts']?[0]?['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 8 — Low Motivation Button: Validating, empathetic message
  // ---------------------------------------------------------------------------
  Future<String?> generateLowMotivationMessage(UserModel user) async {
    final name = user.name.split(' ').first;
    final prompt = 
        'A user named $name opened the "Low Motivation" '
        'feature in their health tracking app because they are struggling to stick '
        'to their diet or log their food today. '
        'Write a short, warm, and highly empathetic message (maximum 2 sentences). '
        'Validate their struggle. Reassure them that perfect consistency is a myth, '
        'and that taking a flexible approach today is exactly how long-term habits are built. '
        'DO NOT use any of these words: m' 'issed, of' 'f track, behind, fail' 'ed, '
        'fail' 'ure, pun' 'ish, compen' 'sate, push, tr' 'y harder, che' 'at, ba' 'd, ruin. '
        'Respond with only the plain text message, no JSON, no formatting.';

    final apiKey = _apiKey;
    final uri = Uri.parse('$_baseUrl?key=$apiKey');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.8,
        'maxOutputTokens': 256,
      }
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;
      final text = (responseJson['candidates'] as List?)
          ?.firstOrNull?['content']?['parts']?[0]?['text'] as String?;
      
      return text?.replaceAll(RegExp(r'^"|"$'), '').trim();
    } catch (_) {
      return null;
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Photo Estimate Result model
// ---------------------------------------------------------------------------
class PhotoEstimateResult {
  final List<String> foods;
  final double totalCalories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final String confidence;
  final String portionNotes;
  final String? warningMessage;

  PhotoEstimateResult({
    required this.foods,
    required this.totalCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    required this.confidence,
    required this.portionNotes,
    this.warningMessage,
  });

  factory PhotoEstimateResult.fromJson(Map<String, dynamic> json) {
    final rawFoods = json['foods'];
    final foods = rawFoods is List
        ? rawFoods.map((e) => e.toString()).toList()
        : <String>[];
    return PhotoEstimateResult(
      foods:         foods,
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0,
      protein:       (json['protein']       as num?)?.toDouble() ?? 0,
      carbs:         (json['carbs']         as num?)?.toDouble() ?? 0,
      fat:           (json['fat']           as num?)?.toDouble() ?? 0,
      fibre:         (json['fibre']         as num?)?.toDouble() ?? 0,
      confidence:    json['confidence']     as String? ?? 'low',
      portionNotes:  json['portionNotes']   as String? ?? '',
      warningMessage: json['warningMessage'] as String?,
    );
  }
}

class PhotoEstimationException implements Exception {
  final String message;
  PhotoEstimationException(this.message);
  @override
  String toString() => message;
}
