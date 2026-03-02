// [HEALTH APP] — Gemini AI Service
// Single entry point for ALL Gemini 1.5 Flash calls.
// Every method is async, try/catch wrapped, and returns structured data.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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
  // Feature 6 — Diet Planner: Generate a full-day meal plan.
  // Returns parsed JSON or null on failure.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> generateMealPlan({
    required String lifeSituation,
    required String region,
    required int targetCalories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    List<String> foodPreferences = const [],
  }) async {
    final prefs = foodPreferences.isNotEmpty
        ? 'Food preferences / restrictions: ${foodPreferences.join(', ')}.'
        : '';
    final currency = _currencyFor(region);
    final prompt = '''
Generate a full day meal plan for a $lifeSituation in $region.
Daily budget: approximately $currency 150.
Calorie target: $targetCalories kcal.
Protein: ${proteinG.toStringAsFixed(0)}g, Carbs: ${carbsG.toStringAsFixed(0)}g, Fat: ${fatG.toStringAsFixed(0)}g.
$prefs
Provide 4 meals: breakfast, lunch, dinner, snack.
For each meal include: meal_name, time_suggestion, foods (array of {name, quantity_description}), calories, protein_g, carbs_g, fat_g.
Prioritise high-protein, affordable, locally available foods in $region.
Respond in pure valid JSON only. No explanation, no markdown, no preamble.
Format: {"meals": [ { "meal_type": "breakfast", "meal_name": "...", "time_suggestion": "...", "foods": [...], "calories": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0 } ]}
''';
    return _sendJsonPrompt(prompt);
  }

  // ---------------------------------------------------------------------------
  // Feature 6 — Recipe Generator.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> generateRecipe({
    required String dishOrIngredient,
    required String region,
    List<String> foodPreferences = const [],
  }) async {
    final prefs = foodPreferences.isNotEmpty
        ? 'Food preferences / restrictions: ${foodPreferences.join(', ')}.'
        : '';
    final prompt = '''
Generate a detailed recipe for "$dishOrIngredient" suitable for a user in $region.
$prefs
Include: recipe_name, servings, prep_time_minutes, cook_time_minutes,
ingredients (array of {name, quantity}), steps (array of strings),
nutrition_per_serving: { calories, protein_g, carbs_g, fat_g }.
Respond in pure valid JSON only. No explanation, no markdown, no preamble.
''';
    return _sendJsonPrompt(prompt);
  }

  // ---------------------------------------------------------------------------
  // Feature 5 — Photo Calorie Estimator.
  // Accepts image bytes and returns estimated nutrition.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> estimateCaloriesFromPhoto({
    required List<int> imageBytes,
    required String mimeType, // e.g. 'image/jpeg'
  }) async {
    try {
      final prompt = '''
You are a nutrition expert. The user has taken a photo of their meal because they cannot measure it accurately.
Analyse the image and estimate: total calories, protein (g), carbohydrates (g), and fat (g).
Also list the main foods you can identify.
Respond in pure valid JSON only. No explanation, no markdown, no preamble.
Format: {"foods": ["..."], "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "confidence": "low|medium|high", "notes": "..."}
''';
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, Uint8List.fromList(imageBytes)),
        ])
      ];
      final response = await _gemini.generateContent(content);
      final text = response.text ?? '';
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

  // ---------------------------------------------------------------------------
  // Helper: currency symbol by region.
  // ---------------------------------------------------------------------------
  String _currencyFor(String region) {
    switch (region) {
      case 'India': return '₹';
      case 'USA':   return '\$';
      case 'UK':    return '£';
      default:      return '\$';
    }
  }
}
