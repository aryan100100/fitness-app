// [ZCTM] — Gemini Service for Zero-Calorie-Tracking Mode
// All 7 AI calls funnel through a single _callGemini() helper,
// mirroring the direct HTTP pattern used in GeminiService.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../models/zctm/adjustment_card_model.dart';
import '../../models/zctm/goal_reframe_model.dart';
import '../../models/zctm/plate_models.dart';
import '../../models/zctm/waist_models.dart';
import '../../models/zctm/weekly_check_in_models.dart';
import '../../models/zctm/zctm_plan_models.dart';
import '../prompts/zctm_prompts.dart';

// ── Exceptions ───────────────────────────────────────────────────────────────

class ZCTMGeminiException implements Exception {
  final String message;
  const ZCTMGeminiException(this.message);
  @override
  String toString() => 'ZCTMGeminiException: $message';
}

// ── Service ──────────────────────────────────────────────────────────────────

class ZCTMGeminiService {
  ZCTMGeminiService._();
  static final instance = ZCTMGeminiService._();

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1/models/'
      'gemini-2.5-flash:generateContent';

  // ---------------------------------------------------------------------------
  // Generic caller — all text-based prompts funnel through here
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _callGemini({
    required String systemPrompt,
    required Map<String, dynamic> userPayload,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw const ZCTMGeminiException('GEMINI_API_KEY not set in .env');
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': systemPrompt},
            {'text': jsonEncode(userPayload)},
          ],
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
        'responseMimeType': 'application/json',
      },
    });

    final res = await http
        .post(
          Uri.parse('$_endpoint?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw ZCTMGeminiException('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body) as Map<String, dynamic>;
    final text =
        raw['candidates'][0]['content']['parts'][0]['text'] as String;

    // Strip markdown fences the model sometimes adds despite responseMimeType
    final clean = text
        .replaceAll(RegExp(r'^```json\n?', multiLine: false), '')
        .replaceAll(RegExp(r'\n?```$', multiLine: false), '')
        .trim();

    return jsonDecode(clean) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // 1. Weekly Check-In Summary
  // ---------------------------------------------------------------------------
  Future<WeeklyCheckInSummary> generateCheckInSummary(
      WeeklyCheckInInput input) async {
    final result = await _callGemini(
      systemPrompt: ZCTMPrompts.weeklyCheckIn,
      userPayload: input.toJson(),
      temperature: 0.7,
      maxTokens: 512,
    );
    return WeeklyCheckInSummary.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // 2. Auto-Adjustment Card Translation
  // ---------------------------------------------------------------------------
  Future<AdjustmentCard> translateAdjustment(AdjustmentInput input) async {
    final result = await _callGemini(
      systemPrompt: ZCTMPrompts.autoAdjustment,
      userPayload: input.toJson(),
      temperature: 0.6,
      maxTokens: 256,
    );
    return AdjustmentCard.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // 3. ZCTM Protein-First Meal Plan
  // recentMealNames: query meal_plans for last 7 days and pass main dish names.
  // ---------------------------------------------------------------------------
  Future<ZCTMMealPlan> generateZCTMPlan(ZCTMPlanInput input) async {
    final result = await _callGemini(
      systemPrompt: ZCTMPrompts.mealPlan,
      userPayload: input.toJson(),
      temperature: 0.7,
      maxTokens: 8192,
    );
    return ZCTMMealPlan.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // 4. Photo AI — Protein Adequacy (multimodal)
  // imageBytes: JPEG Uint8List from image_picker
  // ---------------------------------------------------------------------------
  Future<PhotoProteinResult> analysePhotoProtein({
    required Uint8List imageBytes,
    required double perMealProteinTargetG,
    required String mealType,
    required String lifeSituation,
  }) async {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw const ZCTMGeminiException('GEMINI_API_KEY not set in .env');
    }

    final b64 = base64Encode(imageBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': ZCTMPrompts.photoProteinAdequacy},
            {
              'text': jsonEncode({
                'per_meal_protein_target_g': perMealProteinTargetG,
                'meal_type': mealType,
                'life_situation': lifeSituation,
              })
            },
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': b64,
              }
            },
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 512,
        'responseMimeType': 'application/json',
      },
    });

    final res = await http
        .post(
          Uri.parse('$_endpoint?key=$key'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 40));

    if (res.statusCode != 200) {
      throw ZCTMGeminiException('Photo HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body) as Map<String, dynamic>;
    final text =
        raw['candidates'][0]['content']['parts'][0]['text'] as String;
    return PhotoProteinResult.fromJson(
        jsonDecode(text) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // 5. Plate Method Inference
  // ---------------------------------------------------------------------------
  Future<PlateInferenceResult> inferPlateProtein(PlateInput input) async {
    final result = await _callGemini(
      systemPrompt: ZCTMPrompts.plateMethod,
      userPayload: input.toJson(),
      temperature: 0.3,
      maxTokens: 384,
    );
    return PlateInferenceResult.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // 6. Waist Trend Contextualisation
  // ---------------------------------------------------------------------------
  Future<WaistContextMessage> contextualiseWaistTrend(
      WaistContextInput input) async {
    final result = await _callGemini(
      systemPrompt: ZCTMPrompts.waistContext,
      userPayload: input.toJson(),
      temperature: 0.7,
      maxTokens: 384,
    );
    return WaistContextMessage.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // 7. Goal Reframing
  // ---------------------------------------------------------------------------
  Future<GoalReframeResult> reframeGoal(GoalInput input) async {
    final result = await _callGemini(
      systemPrompt: ZCTMPrompts.goalReframe,
      userPayload: input.toJson(),
      temperature: 0.75,
      maxTokens: 512,
    );
    return GoalReframeResult.fromJson(result);
  }
}
