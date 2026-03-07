// [HEALTH APP] — Gemini AI Service
// Single entry point for ALL Gemini 1.5 Flash calls.
// Every method is async, try/catch wrapped, and returns structured data.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/meal_plan_result.dart';
import '../../models/recipe_result.dart';
import '../../models/user_model.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  GenerativeModel? _model;

  GenerativeModel get _gemini {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    );
    return _model!;
  }

  // ---------------------------------------------------------------------------
  // Internal helper: sends a text prompt, parses JSON response.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _sendJsonPrompt(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _gemini.generateContent(content);
      final text = response.text ?? '';
      // Strip any accidental markdown fences
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 5 — Diet Planner: Generate a full-day meal plan.
  // Full spec prompt: all 5 macros, goal, pantry foods, life-situation rules.
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
        ? 'losing weight'
        : user.goal == 'gain'
            ? 'gaining weight'
            : 'maintaining weight';

    final prompt = 'You are an expert nutritionist and meal planner. '
        'Generate a complete one-day meal plan for a real person with this profile:\n'
        '- Life situation: ${user.lifeSituation}\n'
        '- Region: ${user.region}\n'
        '- Daily calorie target: ${user.targetCalories.toInt()} kcal\n'
        '- Protein target: ${user.proteinG.toInt()}g\n'
        '- Carbohydrates target: ${user.carbsG.toInt()}g\n'
        '- Fat target: ${user.fatG.toInt()}g\n'
        '- Fibre target: ${user.fiberG.toInt()}g\n'
        '- Goal: $goalLabel\n'
        '- Available foods today: $foodsLine\n'
        '- Food preferences: $prefsLine\n\n'
        'Rules:\n'
        '- Build the plan primarily around available foods if listed. Small additions (spices, condiments) are OK.\n'
        '- For hostel_student: no-cook or minimal prep (hot water/microwave). Student budget.\n'
        '- For office_worker: packable, quick-prep, or nearby options.\n'
        '- For work_from_home or homemaker: home-cooked meals with full recipes.\n'
        '- Hit calorie and protein targets within 5%.\n'
        '- Exactly 4 meals: breakfast, lunch, dinner, snack.\n'
        '- Respond ONLY in valid JSON, no markdown, no code fences:\n'
        '{"planDate":"$today","totalCalories":0,"totalProtein":0,"totalCarbs":0,"totalFat":0,"totalFibre":0,'
        '"meals":[{"mealType":"breakfast","mealName":"string","items":[{"name":"string","quantity":"string",'
        '"calories":0,"protein":0,"carbs":0,"fat":0,"fibre":0}],'
        '"totalCalories":0,"totalProtein":0,"totalCarbs":0,"totalFat":0,"totalFibre":0,"prepNote":"string"}]}';

    try {
      final raw = await _sendJsonPrompt(prompt);
      if (raw == null) return null;
      return MealPlanResult.fromJson(raw);
    } catch (e) {
      debugPrint('[GEMINI] generateMealPlan parse error: $e');
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
            '${remCarbs!.toInt()}g carbs, ${remFat!.toInt()}g fat. '
        : '';

    final prompt = 'Generate a detailed recipe for: $query. '
        'User: region ${user.region}, life situation ${user.lifeSituation}. '
        '$macroLine'
        'Respond ONLY in valid JSON, no markdown, no code fences: '
        '{"recipeName":"string","servings":1,"prepTimeMinutes":0,"cookTimeMinutes":0,'
        '"ingredients":[{"name":"string","quantity":"string","gramsEquivalent":0}],'
        '"instructions":["string"],'
        '"nutritionPerServing":{"calories":0,"protein":0,"carbs":0,"fat":0,"fibre":0},'
        '"macroNote":"string"}';

    try {
      final raw = await _sendJsonPrompt(prompt);
      if (raw == null) return null;
      return RecipeResult.fromJson(raw);
    } catch (e) {
      debugPrint('[GEMINI] generateRecipeResult parse error: $e');
      return null;
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Feature 4 — Photo Calorie Estimator (Vision).
  // Returns PhotoEstimateResult or throws PhotoEstimationException on failure.
  // ---------------------------------------------------------------------------
  Future<PhotoEstimateResult> estimateMealFromPhoto(
      List<int> imageBytes, String mimeType) async {
    const systemPrompt = 'You are a nutrition expert analyzing a photo of food. '
        'The user cannot measure this meal accurately. Analyze the image carefully '
        'and provide your best estimate. Consider typical portion sizes and standard '
        'recipes. Respond ONLY in valid JSON with no explanation, no markdown, no '
        'code fences. Use exactly this structure: '
        '{ "foods": ["food item 1", "food item 2"], "totalCalories": number, '
        '"protein": number, "carbs": number, "fat": number, "fibre": number, '
        '"confidence": "low" or "medium" or "high", '
        '"portionNotes": "brief note about portion assumptions", '
        '"warningMessage": "only include if confidence is low or medium — explain why estimate may be off" }';

    try {
      final content = [
        Content.multi([
          TextPart(systemPrompt),
          DataPart(mimeType, Uint8List.fromList(imageBytes)),
        ])
      ];
      final response = await _gemini.generateContent(content);
      final text = response.text ?? '';
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return PhotoEstimateResult.fromJson(json);
    } catch (e) {
      throw PhotoEstimationException('Failed to analyze photo: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 7 — Emergency Button: Encouraging message after adjustment.
  // ---------------------------------------------------------------------------
  Future<String?> generateEmergencyMessage({
    required int caloriesOver,
    required String adjustmentType, // 'distribute_week' | 'push_date'
  }) async {
    final actionDesc = adjustmentType == 'distribute_week'
        ? 'they will distribute the extra $caloriesOver calories across the rest of the week'
        : 'they will push their goal date back by a few days';
    final prompt = '''
A user is tracking their diet and went over their calorie target today by $caloriesOver calories.
They chose to handle it by: $actionDesc.
Write a short, warm, encouraging message (2-3 sentences) that is non-judgmental and motivating.
Respond with only the plain text message. No JSON, no formatting.
''';
    try {
      final content = [Content.text(prompt)];
      final response = await _gemini.generateContent(content);
      return response.text?.trim();
    } catch (e) {
      return null;
    }
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
  final String confidence; // 'low' | 'medium' | 'high'
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
    List<String> foods = [];
    if (rawFoods is List) {
      foods = rawFoods.map((e) => e.toString()).toList();
    }
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
