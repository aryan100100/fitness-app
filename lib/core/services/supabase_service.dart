// [HEALTH APP] — Supabase Service
// Centralised data access layer. All DB reads/writes go through this class.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../models/food_log_model.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  /// Upsert a user row after onboarding completion.
  /// Uses onConflict: 'id' so re-running onboarding never fails on a duplicate PK.
  Future<void> upsertUser(UserModel user) async {
    await _client.from('users').upsert(
      user.toJson(),
      onConflict: 'id',
    );
  }

  /// Verify a user row exists after insert — confirms RLS and schema are working.
  Future<bool> verifyUserExists(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return data != null;
    } catch (_) {
      return false;
    }
  }

  /// Fetch the current user's profile from Supabase.
  Future<UserModel?> fetchCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  /// Update specific fields on the user's profile.
  Future<void> updateUser(Map<String, dynamic> fields) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('users').update(fields).eq('id', userId);
  }

  // ---------------------------------------------------------------------------
  // Food Logs
  // ---------------------------------------------------------------------------

  /// Insert a food log entry.
  Future<void> logFood(FoodLogModel entry) async {
    await _client.from('food_logs').insert(entry.toJson());
  }

  /// Fetch all food logs for a given date.
  Future<List<FoodLogModel>> fetchLogsForDate(String date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .eq('date', date)
        .order('created_at');
    return (data as List).map((e) => FoodLogModel.fromJson(e)).toList();
  }

  /// Fetch the most recently logged foods (for quick-add).
  Future<List<FoodLogModel>> fetchRecentFoods({int limit = 10}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('food_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => FoodLogModel.fromJson(e)).toList();
  }

  // ---------------------------------------------------------------------------
  // Daily Targets (Emergency Button overrides)
  // ---------------------------------------------------------------------------

  /// Fetch target calories for a specific date (returns null if no override exists).
  Future<double?> fetchDailyTargetOverride(String date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client
        .from('daily_targets')
        .select()
        .eq('user_id', userId)
        .eq('date', date)
        .maybeSingle();
    if (data == null) return null;
    return (data['target_calories'] as num).toDouble();
  }

  /// Upsert a daily target override for a given date.
  Future<void> upsertDailyTarget(String date, double targetCalories) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('daily_targets').upsert({
      'user_id': userId,
      'date': date,
      'target_calories': targetCalories,
    });
  }

  // ---------------------------------------------------------------------------
  // Meal Plans
  // ---------------------------------------------------------------------------

  /// Save an AI-generated meal plan for a date.
  Future<void> saveMealPlan(String date, Map<String, dynamic> planData) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('meal_plans').upsert({
      'user_id': userId,
      'date': date,
      'plan_data': planData,
    });
  }

  /// Fetch the saved meal plan for a date.
  Future<Map<String, dynamic>?> fetchMealPlan(String date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client
        .from('meal_plans')
        .select()
        .eq('user_id', userId)
        .eq('date', date)
        .maybeSingle();
    return data?['plan_data'] as Map<String, dynamic>?;
  }
}
