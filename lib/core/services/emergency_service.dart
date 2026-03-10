// [HEALTH APP] — Emergency Service (Feature 6)
// All safety-check logic, redistribution math, Supabase writes, and
// intervention-threshold detection for the Emergency Button feature.
// Calorie floors: 1500 kcal (male), 1200 kcal (female).

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

// ---------------------------------------------------------------------------
// Intervention level — how often the user has triggered the feature
// ---------------------------------------------------------------------------
enum InterventionLevel { none, mild, strong }

// ---------------------------------------------------------------------------
// Redistribution plan — what Option A looks like for this user/overage
// ---------------------------------------------------------------------------
class RedistributionPlan {
  final double newDailyTarget;
  final double dailyReduction;
  final int daysAffected;
  final DateTime backToNormalOn;
  final bool spillsToNextWeek;

  const RedistributionPlan({
    required this.newDailyTarget,
    required this.dailyReduction,
    required this.daysAffected,
    required this.backToNormalOn,
    required this.spillsToNextWeek,
  });
}

// ---------------------------------------------------------------------------
// Available options — result of all 4 safety checks
// ---------------------------------------------------------------------------
class EmergencyOptions {
  final bool showOptionA;
  final bool optionAEnabled;            // false = show greyed with reason
  final String? optionABlockReason;
  final RedistributionPlan? planA;
  final bool showOptionB;
  final int extraDaysB;
  final String newGoalDateLabel;        // human-readable "15 Apr 2026"
  final bool recommendB;                // true for >1500 kcal overage
  final InterventionLevel interventionLevel;
  final String? interventionMessage;

  const EmergencyOptions({
    required this.showOptionA,
    required this.optionAEnabled,
    this.optionABlockReason,
    this.planA,
    required this.showOptionB,
    required this.extraDaysB,
    required this.newGoalDateLabel,
    this.recommendB = false,
    required this.interventionLevel,
    this.interventionMessage,
  });
}

// ---------------------------------------------------------------------------
// EmergencyService — singleton
// ---------------------------------------------------------------------------
class EmergencyService {
  EmergencyService._();
  static final EmergencyService instance = EmergencyService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Calorie floors by biological sex
  static double calorieFloor(String biologicalSex) =>
      biologicalSex == 'female' ? 1200 : 1500;

  // Max daily reduction allowed (beyond existing deficit)
  static const double _maxDailyReduction = 300;

  // ---------------------------------------------------------------------------
  // Master entry point — run all checks, return available options
  // ---------------------------------------------------------------------------
  Future<EmergencyOptions> getAvailableOptions({
    required UserModel user,
    required double overageKcal,
    required int daysRemainingInWeek,  // tomorrow through Sunday
  }) async {
    final userId = user.id ?? '';
    final floor = calorieFloor(user.biologicalSex);
    final currentTarget = user.targetCalories;
    final deficit = (user.dailyDeficitSurplus ?? 0).abs(); // existing daily deficit

    // Intervention check
    final intervention = await checkInterventionThreshold(userId);
    final (interventionMsg) = _interventionMessage(intervention);

    // ── Safety Check 4: already at/near floor ──────────────────────────────
    if (currentTarget <= floor + 100) {
      return EmergencyOptions(
        showOptionA: true,
        optionAEnabled: false,
        optionABlockReason:
            "Your daily target is already at its lowest safe level, so adjusting this week isn't possible. Extending your timeline is the right path forward.",
        showOptionB: true,
        extraDaysB: _calculateExtraDays(overageKcal, deficit),
        newGoalDateLabel: _newGoalDateLabel(user.goalEndDate, _calculateExtraDays(overageKcal, deficit)),
        interventionLevel: intervention,
        interventionMessage: interventionMsg,
      );
    }

    // ── Build redistribution plan ─────────────────────────────────────────
    final (plan, blockReason) = _buildRedistributionPlan(
      overageKcal: overageKcal,
      currentTarget: currentTarget,
      floor: floor,
      daysRemaining: daysRemainingInWeek,
      deficit: deficit,
    );

    final optionAEnabled = plan != null;
    final recommendB = overageKcal > 1500;

    return EmergencyOptions(
      showOptionA: true,
      optionAEnabled: optionAEnabled,
      optionABlockReason: blockReason,
      planA: plan,
      showOptionB: true,
      extraDaysB: _calculateExtraDays(overageKcal, deficit),
      newGoalDateLabel: _newGoalDateLabel(user.goalEndDate, _calculateExtraDays(overageKcal, deficit)),
      recommendB: recommendB,
      interventionLevel: intervention,
      interventionMessage: interventionMsg,
    );
  }

  // ---------------------------------------------------------------------------
  // Build redistribution plan with all safety caps applied
  // ---------------------------------------------------------------------------
  (RedistributionPlan?, String?) _buildRedistributionPlan({
    required double overageKcal,
    required double currentTarget,
    required double floor,
    required int daysRemaining,
    required double deficit,
  }) {
    if (daysRemaining <= 0) {
      return (null, 'There are no remaining days this week to spread the adjustment across.');
    }

    double rawReduction = overageKcal / daysRemaining;
    bool spillsToNextWeek = false;

    // ── Safety Check 2: cap daily reduction at 300 kcal ───────────────────
    if (rawReduction > _maxDailyReduction) {
      rawReduction = _maxDailyReduction;
      spillsToNextWeek = true;
    }

    final newDailyTarget = currentTarget - rawReduction;

    // ── Safety Check 1: floor protection ──────────────────────────────────
    if (newDailyTarget < floor) {
      return (
        null,
        "Spreading this week's extra calories would bring your daily target below the safe minimum of ${floor.toInt()} kcal. Extending your timeline is the safer option."
      );
    }

    // Calculate how many days this redistribution covers
    final daysNeeded = spillsToNextWeek
        ? (overageKcal / _maxDailyReduction).ceil()
        : daysRemaining;

    final now = DateTime.now();
    final backToNormal = now.add(Duration(days: daysNeeded));

    return (
      RedistributionPlan(
        newDailyTarget: newDailyTarget,
        dailyReduction: rawReduction,
        daysAffected: daysNeeded,
        backToNormalOn: backToNormal,
        spillsToNextWeek: spillsToNextWeek,
      ),
      null,
    );
  }

  // ---------------------------------------------------------------------------
  // Calculate extra days for Option B (7,700 kcal/kg estimate)
  // ---------------------------------------------------------------------------
  int _calculateExtraDays(double overageKcal, double dailyDeficit) {
    if (dailyDeficit <= 0) return 1;
    return (overageKcal / dailyDeficit).ceil().clamp(1, 30);
  }

  String _newGoalDateLabel(String? currentGoalEndDate, int extraDays) {
    DateTime base;
    if (currentGoalEndDate != null && currentGoalEndDate.isNotEmpty) {
      base = DateTime.tryParse(currentGoalEndDate) ?? DateTime.now();
    } else {
      base = DateTime.now().add(const Duration(days: 90));
    }
    final newDate = base.add(Duration(days: extraDays));
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${newDate.day} ${months[newDate.month]} ${newDate.year}';
  }

  // ---------------------------------------------------------------------------
  // Apply Option A — write daily_targets override rows
  // ---------------------------------------------------------------------------
  Future<void> applyRedistribution({
    required String userId,
    required RedistributionPlan plan,
  }) async {
    final now = DateTime.now();
    final rows = <Map<String, dynamic>>[];

    for (int i = 1; i <= plan.daysAffected; i++) {
      final date = now.add(Duration(days: i));
      final dateStr = _dateStr(date);
      rows.add({
        'user_id': userId,
        'date': dateStr,
        'target_calories': plan.newDailyTarget.round(),
        'is_emergency_override': true,
        'override_expires_at': _dateStr(plan.backToNormalOn),
      });
    }

    await _client.from('daily_targets').upsert(rows, onConflict: 'user_id,date');
    debugPrint('[EMERGENCY] Redistribution applied: ${rows.length} override rows');
  }

  // ---------------------------------------------------------------------------
  // Apply Option B — extend goal date in users table
  // ---------------------------------------------------------------------------
  Future<void> applyDateExtension({
    required String userId,
    required int extraDays,
    required String? currentGoalEndDate,
  }) async {
    DateTime base;
    if (currentGoalEndDate != null && currentGoalEndDate.isNotEmpty) {
      base = DateTime.tryParse(currentGoalEndDate) ?? DateTime.now();
    } else {
      base = DateTime.now().add(const Duration(days: 90));
    }
    final newDate = base.add(Duration(days: extraDays));
    final newDateStr = _dateStr(newDate);

    await _client
        .from('users')
        .update({'goal_end_date': newDateStr})
        .eq('id', userId);

    debugPrint('[EMERGENCY] Goal date extended to $newDateStr');
  }

  // ---------------------------------------------------------------------------
  // Log usage — inserts into emergency_button_logs, increments counter
  // ---------------------------------------------------------------------------
  Future<void> logUsage({
    required String userId,
    required double overageKcal,
    required String optionChosen, // 'redistribute' | 'extend_date'
  }) async {
    try {
      final weekNumber = _isoWeekNumber(DateTime.now());
      await _client.from('emergency_button_logs').insert({
        'user_id': userId,
        'overage_kcal': overageKcal.round(),
        'option_chosen': optionChosen,
        'week_number': weekNumber,
      });

      // Increment counter on users table
      await _client.rpc('increment_emergency_count', params: {'uid': userId})
          .catchError((_) async {
        // Fallback if RPC not created: manual increment via select+update
        final row = await _client
            .from('users')
            .select('emergency_button_count')
            .eq('id', userId)
            .single();
        final current = (row['emergency_button_count'] as int?) ?? 0;
        await _client.from('users').update({
          'emergency_button_count': current + 1,
          'last_emergency_use': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      });
    } catch (e) {
      debugPrint('[EMERGENCY] logUsage error (non-critical): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Intervention threshold check
  // ---------------------------------------------------------------------------
  Future<InterventionLevel> checkInterventionThreshold(String userId) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = _dateTimeStr(now.subtract(const Duration(days: 7)));
      final fourteenDaysAgo = _dateTimeStr(now.subtract(const Duration(days: 14)));

      final recent = await _client
          .from('emergency_button_logs')
          .select('used_at, week_number')
          .eq('user_id', userId)
          .gte('used_at', fourteenDaysAgo)
          .order('used_at', ascending: false);

      final logs = recent as List;

      // Strong: 4+ uses in last 7 days OR 5 consecutive daily uses
      final last7 = logs.where((r) {
        final used = DateTime.tryParse(r['used_at'] as String? ?? '');
        return used != null && used.isAfter(DateTime.tryParse(sevenDaysAgo)!);
      }).toList();

      if (last7.length >= 4) return InterventionLevel.strong;

      // Check 5 consecutive daily uses
      if (last7.length >= 5) {
        final dates = last7.map((r) {
          final used = DateTime.tryParse(r['used_at'] as String? ?? '');
          return used != null ? _dateStr(used) : '';
        }).toSet();
        bool consecutive = true;
        for (int i = 0; i < 5; i++) {
          if (!dates.contains(_dateStr(now.subtract(Duration(days: i))))) {
            consecutive = false;
            break;
          }
        }
        if (consecutive) return InterventionLevel.strong;
      }

      // Mild: >2 uses in last 7 days
      if (last7.length > 2) return InterventionLevel.mild;

      return InterventionLevel.none;
    } catch (e) {
      debugPrint('[EMERGENCY] checkInterventionThreshold error: $e');
      return InterventionLevel.none;
    }
  }

  // ---------------------------------------------------------------------------
  // Helper — get today's active override target (null if none)
  // ---------------------------------------------------------------------------
  Future<double?> getTodayOverrideTarget(String userId) async {
    try {
      final today = _dateStr(DateTime.now());
      final row = await _client
          .from('daily_targets')
          .select('target_calories')
          .eq('user_id', userId)
          .eq('date', today)
          .eq('is_emergency_override', true)
          .maybeSingle();
      if (row == null) return null;
      return (row['target_calories'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Days remaining in current ISO week (Mon–Sun), not counting today
  // Tomorrow through next Sunday
  // ---------------------------------------------------------------------------
  static int daysRemainingInWeek() {
    final now = DateTime.now();
    // weekday: Mon=1, Sun=7
    return 7 - now.weekday; // days after today until end of week
  }

  // Human-readable date for back-to-normal
  static String backToNormalLabel(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month]}';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------
  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _dateTimeStr(DateTime dt) => dt.toIso8601String();

  int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1)
        .add(Duration(days: 4 - DateTime(thursday.year, 1, 1).weekday));
    return ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
  }

  String? _interventionMessage(InterventionLevel level) {
    return switch (level) {
      InterventionLevel.mild =>
        "You've been using this feature quite a bit recently. "
        "That sometimes means your current targets feel a little ambitious. "
        "Would you like to look at a more comfortable daily target?",
      InterventionLevel.strong =>
        "Hitting your daily target has been consistently tricky — and that's completely normal. "
        "It might mean your targets need a small adjustment rather than frequent corrections.",
      InterventionLevel.none => null,
    };
  }
}
