// [HEALTH APP] — TDEE Recalibration Service (Feature 3)
// Background service that silently recalibrates the user's TDEE
// after 14+ days of consistent logging. Fails silently in all error cases.

import 'package:supabase_flutter/supabase_flutter.dart';

class TDEERecalibrationService {
  TDEERecalibrationService._();
  static final TDEERecalibrationService instance =
      TDEERecalibrationService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Main entry point — call from DashboardScreen.initState()
  // All logic is wrapped in a top-level try/catch. Silent error handling guaranteed.
  // ---------------------------------------------------------------------------
  Future<void> checkAndRecalibrate(String userId) async {
    try {
      await _runRecalibration(userId);
    } catch (_) {
      // Silent error — user experience is never disrupted
    }
  }

  Future<void> _runRecalibration(String userId) async {
    // Fetch user data
    final userData = await _client
        .from('users')
        .select(
            'tdee, daily_deficit_surplus, goal_start_date, tdee_calibration_date, tdee_confidence, target_calories')
        .eq('id', userId)
        .maybeSingle();

    if (userData == null) return;

    final formulaTDEE =
        (userData['tdee'] as num?)?.toDouble() ?? 0;
    final dailyDefSurplus =
        (userData['daily_deficit_surplus'] as num?)?.toDouble() ?? 0;
    final goalStartStr = userData['goal_start_date'] as String?;
    final calibrationDateStr =
        userData['tdee_calibration_date'] as String?;

    if (formulaTDEE == 0) return;

    // ---------------------------------------------------------------------------
    // Eligibility Check 1 — 14+ days since onboarding
    // ---------------------------------------------------------------------------
    if (goalStartStr == null) return;
    final goalStart = DateTime.tryParse(goalStartStr);
    if (goalStart == null) return;
    final daysSince = DateTime.now().difference(goalStart).inDays;
    if (daysSince < 14) return;

    // ---------------------------------------------------------------------------
    // Eligibility Check 2 — Do not recalibrate more than once per 14 days
    // ---------------------------------------------------------------------------
    if (calibrationDateStr != null) {
      final lastCal = DateTime.tryParse(calibrationDateStr);
      if (lastCal != null) {
        final daysSinceCalibration =
            DateTime.now().difference(lastCal).inDays;
        if (daysSinceCalibration < 14) return;
      }
    }

    // ---------------------------------------------------------------------------
    // Eligibility Check 3 — At least 10 log days in last 14 days
    // ---------------------------------------------------------------------------
    final from14 =
        _dateStr(DateTime.now().subtract(const Duration(days: 14)));
    final toStr = _dateStr(DateTime.now());

    final logData = await _client
        .from('food_logs')
        .select('date, calories')
        .eq('user_id', userId)
        .gte('date', from14)
        .lte('date', toStr);

    final Map<String, double> dailyCalories = {};
    for (final row in logData as List) {
      final date = row['date'] as String?;
      final cal = (row['calories'] as num?)?.toDouble() ?? 0;
      if (date != null) {
        dailyCalories[date] = (dailyCalories[date] ?? 0) + cal;
      }
    }

    if (dailyCalories.length < 10) {
      // Update confidence to inconsistent and return
      await _client.from('users').update({
        'tdee_confidence': 'inconsistent',
      }).eq('id', userId);
      return;
    }

    // ---------------------------------------------------------------------------
    // Eligibility Check 4 — Weight logs (graceful skip if table doesn't exist)
    // ---------------------------------------------------------------------------
    List<Map<String, dynamic>> weightLogs = [];
    try {
      final wData = await _client
          .from('weight_logs')
          .select('weight_kg, logged_date')
          .eq('user_id', userId)
          .gte('logged_date', from14)
          .lte('logged_date', toStr)
          .order('logged_date');
      weightLogs = List<Map<String, dynamic>>.from(wData as List);
    } catch (_) {
      // weight_logs table doesn't exist yet — skip recalibration silently
      return;
    }

    if (weightLogs.length < 3) return;

    // ---------------------------------------------------------------------------
    // Step 1 — Average daily logged intake
    // ---------------------------------------------------------------------------
    final totalLogged =
        dailyCalories.values.fold(0.0, (sum, c) => sum + c);
    final avgDailyIntake = totalLogged / dailyCalories.length;

    // ---------------------------------------------------------------------------
    // Step 2 — Total weight change over 14 days
    // ---------------------------------------------------------------------------
    final firstWeight =
        (weightLogs.first['weight_kg'] as num?)?.toDouble() ?? 0;
    final lastWeight =
        (weightLogs.last['weight_kg'] as num?)?.toDouble() ?? 0;
    final weightChange = lastWeight - firstWeight; // negative = loss

    // ---------------------------------------------------------------------------
    // Step 3 — Implied daily calorie difference
    // ---------------------------------------------------------------------------
    final totalCalDiff = weightChange * 7700;
    final dailyCalDiff = totalCalDiff / 14;

    // ---------------------------------------------------------------------------
    // Step 4 — Back-calculate true TDEE
    // avgIntake was the calories at which this weight change occurred
    // If losing: add back the deficit → true TDEE = intake + deficit
    // ---------------------------------------------------------------------------
    final recalibratedTDEE = avgDailyIntake + dailyCalDiff;

    // ---------------------------------------------------------------------------
    // Step 5 — Blend formula TDEE (40%) with recalibrated TDEE (60%)
    // Prevents overcorrection on a single noisy 14-day window
    // ---------------------------------------------------------------------------
    final finalTDEE =
        (formulaTDEE * 0.4) + (recalibratedTDEE * 0.6);

    // Sanity bounds — reject obviously wrong values
    if (finalTDEE < 800 || finalTDEE > 6000) return;

    // ---------------------------------------------------------------------------
    // Step 6 — Recalculate target calories using stored pace
    // ---------------------------------------------------------------------------
    final newTargetCalories = finalTDEE + dailyDefSurplus;

    // ---------------------------------------------------------------------------
    // Step 7 — Update users table
    // ---------------------------------------------------------------------------
    await _client.from('users').update({
      'tdee':                  finalTDEE.roundToDouble(),
      'target_calories':       newTargetCalories.roundToDouble(),
      'tdee_recalibrated':     finalTDEE.roundToDouble(),
      'tdee_calibration_date': toStr,
      'tdee_confidence':       'calibrated',
    }).eq('id', userId);
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
