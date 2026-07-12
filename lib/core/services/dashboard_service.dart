// [HEALTH APP] — Dashboard Service
// All data queries for the dashboard. Each method has its own try/catch
// so a single error never blocks the rest of the screen from loading.
// Auth errors (JWT/token expiry) are explicitly rethrown so the global
// session handler in _AppRouter can redirect the user to WelcomeScreen.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/dashboard_summary.dart';
import '../../models/food_log_model.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Today's calorie / macro totals
  // ---------------------------------------------------------------------------
  Future<Map<String, double>> getTodaysTotals(
      String userId, String date) async {
    try {
      final data = await _client
          .from('food_logs')
          .select('calories, protein_g, carbs_g, fat_g, fibre_g')
          .eq('user_id', userId)
          .eq('date', date);

      double cal = 0, prot = 0, carbs = 0, fat = 0, fibre = 0;
      for (final row in data as List) {
        cal   += (row['calories']  as num?)?.toDouble() ?? 0;
        prot  += (row['protein_g'] as num?)?.toDouble() ?? 0;
        carbs += (row['carbs_g']   as num?)?.toDouble() ?? 0;
        fat   += (row['fat_g']     as num?)?.toDouble() ?? 0;
        fibre += (row['fibre_g']   as num?)?.toDouble() ?? 0;
      }
      return {
        'calories': cal,
        'protein': prot,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
      };
    } on AuthException {
      rethrow; // Auth errors must not be silenced — propagate to _AppRouter
    } catch (_) {
      return {
        'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'fibre': 0
      };
    }
  }

  // ---------------------------------------------------------------------------
  // All food logs for a specific meal type today
  // ---------------------------------------------------------------------------
  Future<List<FoodLogModel>> getMealLogs(
      String userId, String date, String mealType) async {
    try {
      final data = await _client
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .eq('date', date)
          .eq('meal_type', mealType)
          .order('created_at');
      return (data as List).map((e) => FoodLogModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // User targets from users table
  // ---------------------------------------------------------------------------
  Future<Map<String, double>> getUserTargets(String userId) async {
    try {
      final today = _dateStr(DateTime.now());

      // ── Check for active emergency override first ────────────────────────
      final override = await _client
          .from('daily_targets')
          .select('target_calories')
          .eq('user_id', userId)
          .eq('date', today)
          .eq('is_emergency_override', true)
          .maybeSingle();

      final data = await _client
          .from('users')
          .select(
              'target_calories, protein_g, carbs_g, fat_g, fiber_g, tdee, weekly_pace_percent, daily_deficit_surplus')
          .eq('id', userId)
          .single();

      final standardTarget = (data['target_calories'] as num?)?.toDouble() ?? 2000;
      final effectiveTarget = override != null
          ? (override['target_calories'] as num?)?.toDouble() ?? standardTarget
          : standardTarget;

      return {
        'targetCalories':      effectiveTarget,
        'targetProtein':       (data['protein_g']             as num?)?.toDouble() ?? 150,
        'targetCarbs':         (data['carbs_g']               as num?)?.toDouble() ?? 200,
        'targetFat':           (data['fat_g']                 as num?)?.toDouble() ?? 55,
        'targetFibre':         (data['fiber_g']               as num?)?.toDouble() ?? 30,
        'tdee':                (data['tdee']                  as num?)?.toDouble() ?? 2000,
        'weeklyPacePercent':   (data['weekly_pace_percent']   as num?)?.toDouble() ?? 0.75,
        'dailyDeficitSurplus': (data['daily_deficit_surplus'] as num?)?.toDouble() ?? 0,
      };
    } catch (_) {
      return {
        'targetCalories': 2000, 'targetProtein': 150,
        'targetCarbs': 200, 'targetFat': 55, 'targetFibre': 30,
        'tdee': 2000, 'weeklyPacePercent': 0.75, 'dailyDeficitSurplus': 0,
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Streak management moved to StreakService (Feature 8)
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Dashboard Overrides (Feature 8)
  // ---------------------------------------------------------------------------
  Future<String?> getTodayOverride(String userId, String date) async {
    try {
      final data = await _client
          .from('day_overrides')
          .select('override_type')
          .eq('user_id', userId)
          .eq('override_date', date)
          .maybeSingle();
      return data?['override_type'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Weekly summary — Monday to today
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getWeeklySummary(
      String userId, double targetCaloriesPerDay) async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final fromDate = _dateStr(monday);
      final toDate = _dateStr(now);

      final data = await _client
          .from('food_logs')
          .select('calories, date')
          .eq('user_id', userId)
          .gte('date', fromDate)
          .lte('date', toDate);

      double totalCal = 0;
      final Set<String> daysLogged = {};
      for (final row in data as List) {
        totalCal += (row['calories'] as num?)?.toDouble() ?? 0;
        final d = row['date'] as String?;
        if (d != null) daysLogged.add(d);
      }

      final daysSoFar = now.weekday; // 1 = Mon, 7 = Sun
      return {
        'weeklyCaloriesLogged': totalCal,
        'weeklyCaloriesTarget': targetCaloriesPerDay * daysSoFar,
        'weeklyDaysLogged': daysLogged.length,
      };
    } catch (_) {
      return {
        'weeklyCaloriesLogged': 0.0,
        'weeklyCaloriesTarget': 0.0,
        'weeklyDaysLogged': 0,
      };
    }
  }

  // ---------------------------------------------------------------------------
  // TDEE confidence status
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getTDEEConfidenceStatus(
      String userId, DateTime? onboardingDate) async {
    try {
      final now = DateTime.now();
      final daysSinceOnboarding = onboardingDate != null
          ? now.difference(onboardingDate).inDays
          : 0;

      // Count distinct log dates in last 14 days
      final from14 = _dateStr(now.subtract(const Duration(days: 14)));
      final toStr = _dateStr(now);
      final logs = await _client
          .from('food_logs')
          .select('date')
          .eq('user_id', userId)
          .gte('date', from14)
          .lte('date', toStr);

      final Set<String> distinctDates = {};
      for (final row in logs as List) {
        final d = row['date'] as String?;
        if (d != null) distinctDates.add(d);
      }
      final daysLogged = distinctDates.length;

      // Fetch calibration state from users
      final userData = await _client
          .from('users')
          .select('tdee_confidence, tdee_calibration_date')
          .eq('id', userId)
          .maybeSingle();

      final dbConfidence =
          userData?['tdee_confidence'] as String? ?? 'building';

      TDEEConfidence confidence;
      if (daysSinceOnboarding < 14) {
        confidence = TDEEConfidence.building;
      } else if (dbConfidence == 'calibrated') {
        confidence = TDEEConfidence.calibrated;
      } else if (daysLogged < 10) {
        confidence = TDEEConfidence.inconsistent;
      } else {
        confidence = TDEEConfidence.building;
      }

      return {
        'confidence': confidence,
        'daysLogged': daysLogged.clamp(0, 14),
      };
    } catch (_) {
      return {
        'confidence': TDEEConfidence.building,
        'daysLogged': 0,
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a food log entry
  // ---------------------------------------------------------------------------
  Future<bool> deleteFoodLog(String foodLogId) async {
    try {
      await _client.from('food_logs').delete().eq('id', foodLogId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------
  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
