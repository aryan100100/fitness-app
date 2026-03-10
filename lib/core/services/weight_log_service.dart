// [HEALTH APP] — Weight Log Service (Feature 7)
// Handles all weight_logs Supabase reads/writes.
// All methods are try/catch wrapped — never crash.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/weight_log_model.dart';

class WeightLogService {
  WeightLogService._();
  static final WeightLogService instance = WeightLogService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Save a weight entry — upserts on (user_id, logged_at)
  // ---------------------------------------------------------------------------
  Future<void> saveWeight(
    String userId,
    double weightKg, {
    bool isMenstrual = false,
    String? note,
    DateTime? date,
  }) async {
    try {
      final loggedAt = date ?? DateTime.now();
      await _client.from('weight_logs').upsert({
        'user_id': userId,
        'weight_kg': weightKg,
        'logged_at': _dateStr(loggedAt),
        'is_menstrual_phase': isMenstrual,
        if (note != null) 'note': note,
      }, onConflict: 'user_id,logged_at');
      debugPrint('[WEIGHT] Saved $weightKg kg for $userId on ${_dateStr(loggedAt)}');
    } catch (e) {
      debugPrint('[WEIGHT] saveWeight error: $e');
      rethrow; // let the UI catch and show an error
    }
  }

  // ---------------------------------------------------------------------------
  // Get recent weight entries (last N days, one per day — latest if multiple)
  // ---------------------------------------------------------------------------
  Future<List<WeightLog>> getRecentWeights(String userId,
      {int days = 60}) async {
    try {
      final from = _dateStr(DateTime.now().subtract(Duration(days: days)));
      final data = await _client
          .from('weight_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', from)
          .order('logged_at', ascending: true);

      return (data as List).map((e) => WeightLog.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[WEIGHT] getRecentWeights error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Get the 7-day rolling average of the most recent 7 days with entries
  // One entry per distinct day (latest wins if multiple on same day)
  // Returns null if no entries found
  // ---------------------------------------------------------------------------
  Future<double?> getCurrentWeeklyAverage(String userId) async {
    final entries = await getRecentWeights(userId, days: 7);
    if (entries.isEmpty) return null;
    return calculateWeeklyAverage(entries);
  }

  // ---------------------------------------------------------------------------
  // Get the weekly average for the 7 days BEFORE the current 7-day window
  // Used for Δ calculation (Rule 2)
  // ---------------------------------------------------------------------------
  Future<double?> getPreviousWeeklyAverage(String userId) async {
    try {
      final now = DateTime.now();
      final from = _dateStr(now.subtract(const Duration(days: 14)));
      final to = _dateStr(now.subtract(const Duration(days: 7)));

      final data = await _client
          .from('weight_logs')
          .select('weight_kg, logged_at')
          .eq('user_id', userId)
          .gte('logged_at', from)
          .lte('logged_at', to)
          .order('logged_at', ascending: true);

      final entries =
          (data as List).map((e) => WeightLog.fromJson(e)).toList();
      if (entries.isEmpty) return null;
      return calculateWeeklyAverage(entries);
    } catch (e) {
      debugPrint('[WEIGHT] getPreviousWeeklyAverage error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Most recent single entry
  // ---------------------------------------------------------------------------
  Future<WeightLog?> getMostRecentEntry(String userId) async {
    try {
      final data = await _client
          .from('weight_logs')
          .select()
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return WeightLog.fromJson(data);
    } catch (e) {
      debugPrint('[WEIGHT] getMostRecentEntry error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Entries from the last 7 days (for recalculation check)
  // ---------------------------------------------------------------------------
  Future<List<WeightLog>> getLast7DaysEntries(String userId) async {
    return getRecentWeights(userId, days: 7);
  }

  // ---------------------------------------------------------------------------
  // Calculate weekly average from a list of entries.
  // Deduplicates by date (keeps latest entry per day).
  // Pure function — no async.
  // ---------------------------------------------------------------------------
  double calculateWeeklyAverage(List<WeightLog> entries) {
    if (entries.isEmpty) return 0;

    // Deduplicate: one entry per day (last in list wins = most recent created)
    final Map<String, double> byDay = {};
    for (final e in entries) {
      final day = _dateStr(e.loggedAt);
      byDay[day] = e.weightKg; // last write wins
    }

    final weights = byDay.values.toList();
    final sum = weights.fold(0.0, (a, b) => a + b);
    return sum / weights.length;
  }

  // ---------------------------------------------------------------------------
  // Count distinct logging days for the last N days (food logs)
  // Used by Situation 3 check
  // ---------------------------------------------------------------------------
  Future<int> countDistinctFoodLogDays(String userId, {int days = 14}) async {
    try {
      final from = _dateStr(DateTime.now().subtract(Duration(days: days)));
      final data = await _client
          .from('food_logs')
          .select('date')
          .eq('user_id', userId)
          .gte('date', from);

      final Set<String> distinct = {};
      for (final row in data as List) {
        final d = row['date'] as String?;
        if (d != null) distinct.add(d);
      }
      return distinct.length;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Count distinct food log days for last 3 days (Situation 1 gap check)
  // ---------------------------------------------------------------------------
  Future<bool> hasFoodLogsInLastDays(String userId, int days) async {
    try {
      final from = _dateStr(DateTime.now().subtract(Duration(days: days)));
      final data = await _client
          .from('food_logs')
          .select('date')
          .eq('user_id', userId)
          .gte('date', from)
          .limit(1);
      return (data as List).isNotEmpty;
    } catch (_) {
      return true; // fail safe — don't show gap card if we can't check
    }
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------
  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
