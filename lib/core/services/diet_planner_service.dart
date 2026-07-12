// [HEALTH APP] — Diet Planner Service
// Orchestrates meal plan caching (meal_plans table) and batch food logging.
// Never calls Gemini directly — that stays in GeminiService.

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/meal_plan_result.dart';

class DietPlannerService {
  DietPlannerService._();
  static final DietPlannerService instance = DietPlannerService._();

  final _client = Supabase.instance.client;

  /// Set as a side-effect of [loadTodaysPlan] when a cached plan is found.
  /// Null if no plan was loaded or after a fresh generation.
  DateTime? lastLoadedAt;

  // ---------------------------------------------------------------------------
  // Meal plan caching
  // ---------------------------------------------------------------------------

  /// Loads today's saved meal plan for [userId], or null if none exists.
  /// Also sets [lastLoadedAt] to the row's created_at timestamp when found.
  Future<MealPlanResult?> loadTodaysPlan(String userId) async {
    try {
      final today = _today();
      final data = await _client
          .from('meal_plans')
          .select('plan_data, created_at')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();
      if (data == null) return null;
      // Parse and store the timestamp
      final createdAtStr = data['created_at'] as String?;
      lastLoadedAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      final planData = data['plan_data'];
      if (planData == null) return null;
      final json = planData is String
          ? jsonDecode(planData) as Map<String, dynamic>
          : planData as Map<String, dynamic>;
      return MealPlanResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Saves (upserts) a meal plan to [meal_plans] for today.
  Future<void> savePlan(String userId, MealPlanResult plan) async {
    try {
      await _client.from('meal_plans').upsert(
        {
          'user_id': userId,
          'date': _today(),
          'plan_data': plan.toJson(),
        },
        onConflict: 'user_id,date',
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Batch food logging — all items from a PlannedMeal in one insert
  // ---------------------------------------------------------------------------

  /// Inserts all items from [meal] into food_logs as a single batch.
  /// Atomic: either all items are logged or none are.
  Future<void> logMealItems(String userId, PlannedMeal meal) async {
    final today = _today();
    final rows = meal.items.map((item) => {
          'user_id':    userId,
          'date':       today,
          'meal_type':  meal.mealType,
          'food_name':  item.name,
          'quantity_g': item.quantity, // stored as text quantity description
          'calories':   item.calories,
          'protein_g':  item.protein,
          'carbs_g':    item.carbs,
          'fat_g':      item.fat,
          'fibre_g':    item.fibre,
          'food_source': 'ai_plan',
        }).toList();

    await _client.from('food_logs').insert(rows);
  }

  /// Logs a single recipe result (from Recipe tab) as one custom food_logs entry.
  Future<void> logRecipe({
    required String userId,
    required String recipeName,
    required String mealType,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fibre,
    required int servings,
  }) async {
    final today = _today();
    await _client.from('food_logs').insert({
      'user_id':    userId,
      'date':       today,
      'meal_type':  mealType,
      'food_name':  recipeName,
      'quantity_g': servings,
      'calories':   calories,
      'protein_g':  protein,
      'carbs_g':    carbs,
      'fat_g':      fat,
      'fibre_g':    fibre,
      'food_source': 'ai_recipe',
    });
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
