// [HEALTH APP] — Auto Adjustment Service (Feature 7)
// Runs every app open (non-blocking). Checks all 5 situations and returns
// at most 2 cards to surface, in priority order.
// All Supabase writes wrapped in try/catch.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../models/weight_log_model.dart';
import '../../core/utils/tdee_calculator.dart';
import 'weight_log_service.dart';

// ---------------------------------------------------------------------------
// Enums and data models
// ---------------------------------------------------------------------------

enum SituationType {
  loggingGap,         // Situation 1
  goalDateApproaching, // Situation 2
  weightUpdatePrompt,  // Situation 3
  weeklyRecalc,       // Situation 4
  divergence,         // Situation 5
}

enum RecalcOutcome {
  insufficientData,   // < 4 entries this week
  stable,             // |Δ| < 0.3 kg
  menstrualSkip,      // menstrual phase this week
  rapidLoss,          // > 1.5% body weight
  smallChange,        // ≤ 100 kcal → silent
  mediumChange,       // 101–250 kcal → confirm card
  largeChange,        // > 250 kcal → phased
}

class RecalcDetails {
  final double currentWeeklyAvg;
  final double previousWeeklyAvg;
  final double delta;
  final double newTargetCalories;
  final double oldTargetCalories;
  final double newTdee;
  final double newProteinG;
  final double newCarbsG;
  final double newFatG;
  final double calorieDifference;   // abs(new - old)
  final double phasedAdjustment;    // half of calorie diff if large change

  const RecalcDetails({
    required this.currentWeeklyAvg,
    required this.previousWeeklyAvg,
    required this.delta,
    required this.newTargetCalories,
    required this.oldTargetCalories,
    required this.newTdee,
    required this.newProteinG,
    required this.newCarbsG,
    required this.newFatG,
    required this.calorieDifference,
    required this.phasedAdjustment,
  });
}

class WeeklyRecalcResult {
  final RecalcOutcome outcome;
  final String message;            // human-readable explanation for the card
  final RecalcDetails? details;   // non-null when outcome is small/medium/large

  const WeeklyRecalcResult({
    required this.outcome,
    required this.message,
    this.details,
  });
}

class GoalProgressSummary {
  final double startingWeight;
  final double currentAvg;
  final double targetWeight;
  final double totalGoalKg;
  final double changeKg;           // how much has changed so far
  final double progressPercent;    // 0.0–1.0
  final int daysRemaining;
  final bool isAheadOfPace;
  final double suggestedNewTargetWeight; // Option B
  final String suggestedNewGoalDate;     // Option A formatted

  const GoalProgressSummary({
    required this.startingWeight,
    required this.currentAvg,
    required this.targetWeight,
    required this.totalGoalKg,
    required this.changeKg,
    required this.progressPercent,
    required this.daysRemaining,
    required this.isAheadOfPace,
    required this.suggestedNewTargetWeight,
    required this.suggestedNewGoalDate,
  });
}

class DivergenceResult {
  final bool hasDivergence;
  final double expectedChangeKg;
  final double actualChangeKg;

  const DivergenceResult({
    required this.hasDivergence,
    required this.expectedChangeKg,
    required this.actualChangeKg,
  });
}

class AdjustmentSituation {
  final SituationType type;
  final WeeklyRecalcResult? recalcResult;
  final GoalProgressSummary? goalProgress;
  final DivergenceResult? divergenceResult;

  const AdjustmentSituation({
    required this.type,
    this.recalcResult,
    this.goalProgress,
    this.divergenceResult,
  });
}

// ---------------------------------------------------------------------------
// AutoAdjustmentService — singleton
// ---------------------------------------------------------------------------
class AutoAdjustmentService {
  AutoAdjustmentService._();
  static final AutoAdjustmentService instance = AutoAdjustmentService._();

  final _weightSvc = WeightLogService.instance;
  SupabaseClient get _client => Supabase.instance.client;

  // Calorie floors — match TDEECalculator
  static double _floor(String sex) => sex == 'female' ? 1200.0 : 1500.0;
  // Max deficit: 35% below TDEE
  static double _minCalories(double tdee) => tdee * 0.65;

  // ---------------------------------------------------------------------------
  // Master entry point: checks all 5 situations, returns max 1 at a time
  // Priority: Sit4 > Sit1 > Sit5 > Sit2 > Sit3
  // ---------------------------------------------------------------------------
  Future<List<AdjustmentSituation>> checkAllSituations(UserModel user) async {
    try {
      final userId = user.id ?? '';
      final low = user.lowPressureMode;

      // Run all checks in parallel
      final results = await Future.wait([
        _checkSituation4(user, userId),          // Weekly recalc (highest priority)
        _checkSituation1(userId, low),            // Logging gap
        _checkSituation5(user, userId),           // Divergence
        _checkSituation2(user, userId),           // Goal date approaching
        _checkSituation3(user, userId, low),      // Weight update prompt
      ]);

      final situations = <AdjustmentSituation>[];
      for (final s in results) {
        if (s != null) situations.add(s);
      }

      return applyFrequencyLimit(situations);
    } catch (e) {
      debugPrint('[AUTOADJ] checkAllSituations error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Situation 1 — Logging Gap
  // ---------------------------------------------------------------------------
  Future<AdjustmentSituation?> _checkSituation1(
      String userId, bool lowPressure) async {
    final threshold = lowPressure ? 7 : 3;
    final hasLogs = await _weightSvc.hasFoodLogsInLastDays(userId, threshold);
    if (hasLogs) return null;
    return const AdjustmentSituation(type: SituationType.loggingGap);
  }

  // ---------------------------------------------------------------------------
  // Situation 2 — Goal Date Approaching (within 7 days)
  // ---------------------------------------------------------------------------
  Future<AdjustmentSituation?> _checkSituation2(
      UserModel user, String userId) async {
    if (user.goal == 'maintain') return null;
    if (user.goalDateReminderShown) return null;
    if (user.goalEndDate == null) return null;
    if (user.lowPressureMode) return null; // low pressure: manual only

    final goalDate = DateTime.tryParse(user.goalEndDate!);
    if (goalDate == null) return null;
    final daysRemaining = goalDate.difference(DateTime.now()).inDays;
    if (daysRemaining > 7 || daysRemaining < 0) return null;

    // Get current weekly average
    final avg = await _weightSvc.getCurrentWeeklyAverage(userId);
    if (avg == null) return null;

    final progress = _calculateGoalProgress(user, avg, daysRemaining);
    return AdjustmentSituation(
      type: SituationType.goalDateApproaching,
      goalProgress: progress,
    );
  }

  GoalProgressSummary _calculateGoalProgress(
    UserModel user,
    double currentAvg,
    int daysRemaining,
  ) {
    final start = user.weightKg; // weight at onboarding
    final target = user.targetWeightKg ?? start;
    final totalGoal = (start - target).abs();
    final changed = (start - currentAvg).abs();
    final progress = totalGoal > 0 ? (changed / totalGoal).clamp(0.0, 1.0) : 0.0;

    // Pace-based expected change
    final dailyChange = (user.dailyDeficitSurplus?.abs() ?? 0) / 7700;
    final expectedChangeByNow = dailyChange *
        (DateTime.now()
            .difference(
              user.goalStartDate != null
                  ? DateTime.tryParse(user.goalStartDate!) ?? DateTime.now()
                  : DateTime.now(),
            )
            .inDays);
    final isAhead = changed >= expectedChangeByNow;

    // Option A: extend date to match current pace
    final remaining = totalGoal - changed;
    final extraDays = dailyChange > 0
        ? (remaining / dailyChange).ceil()
        : daysRemaining + 30;
    final newDate = DateTime.now().add(Duration(days: extraDays));

    // Option B: target weight achievable at current pace by original date
    final achievable = changed + dailyChange * daysRemaining;
    final newTarget = user.goal == 'lose'
        ? (start - achievable).clamp(start - totalGoal, start)
        : (start + achievable).clamp(start, start + totalGoal);

    return GoalProgressSummary(
      startingWeight: start,
      currentAvg: currentAvg,
      targetWeight: target,
      totalGoalKg: totalGoal,
      changeKg: changed,
      progressPercent: progress,
      daysRemaining: daysRemaining,
      isAheadOfPace: isAhead,
      suggestedNewTargetWeight: newTarget,
      suggestedNewGoalDate: _fmtDate(newDate),
    );
  }

  // ---------------------------------------------------------------------------
  // Situation 3 — Consistent Adherence Prompt
  // ---------------------------------------------------------------------------
  Future<AdjustmentSituation?> _checkSituation3(
      UserModel user, String userId, bool lowPressure) async {
    // Skip if prompted within last 14 days
    if (user.lastSituation3Prompt != null) {
      final last = DateTime.tryParse(user.lastSituation3Prompt!);
      if (last != null &&
          DateTime.now().difference(last).inDays < 14) return null;
    }

    final foodDays = await _weightSvc.countDistinctFoodLogDays(userId, days: 14);
    if (foodDays < 10) return null;

    // Check no weight logged in last 14 days
    final entries = await _weightSvc.getRecentWeights(userId, days: 14);
    if (entries.isNotEmpty) return null;

    return const AdjustmentSituation(type: SituationType.weightUpdatePrompt);
  }

  // ---------------------------------------------------------------------------
  // Situation 4 — Weekly Recalculation (CORE)
  // ---------------------------------------------------------------------------
  Future<AdjustmentSituation?> _checkSituation4(
      UserModel user, String userId) async {
    // Only trigger on check-in day
    if (DateTime.now().weekday != user.checkinDay) return null;

    // Only trigger if not already recalced today/this week
    if (user.lastWeeklyRecalcDate != null) {
      final last = DateTime.tryParse(user.lastWeeklyRecalcDate!);
      if (last != null &&
          DateTime.now().difference(last).inDays < 6) return null;
    }

    final result = await runWeeklyRecalc(user);
    return AdjustmentSituation(
      type: SituationType.weeklyRecalc,
      recalcResult: result,
    );
  }

  Future<WeeklyRecalcResult> runWeeklyRecalc(UserModel user) async {
    final userId = user.id ?? '';
    final entries = await _weightSvc.getLast7DaysEntries(userId);

    // Rule 1 — Minimum 4 distinct days
    final distinctDays = _distinctDays(entries);
    if (distinctDays < 4) {
      return const WeeklyRecalcResult(
        outcome: RecalcOutcome.insufficientData,
        message:
            "We need a few more weigh-ins before updating your plan — try to log your weight a few more times this week.",
      );
    }

    // Rule 3 — Menstrual phase protection (female only)
    if (user.biologicalSex == 'female') {
      final hasMenstrual = entries.any((e) => e.isMenstrualPhase);
      if (hasMenstrual) {
        return const WeeklyRecalcResult(
          outcome: RecalcOutcome.menstrualSkip,
          message:
              "We've skipped this week's update because weight can fluctuate during your period — we'll check again next week.",
        );
      }
    }

    final currentAvg = _weightSvc.calculateWeeklyAverage(entries);
    final previousAvg =
        await _weightSvc.getPreviousWeeklyAverage(userId) ??
            user.previousWeeklyWeight ??
            user.weightKg;

    final delta = currentAvg - previousAvg;

    // Rule 2 — Minimum change threshold of 0.3 kg
    if (delta.abs() < 0.3) {
      return const WeeklyRecalcResult(
        outcome: RecalcOutcome.stable,
        message:
            "Your weight is stable this week — no changes needed to your targets.",
      );
    }

    // Rule 4 — Rapid loss safety check (> 1.5% body weight)
    final rapidThreshold = previousAvg * 0.015;
    if (delta < 0 && delta.abs() > rapidThreshold) {
      return WeeklyRecalcResult(
        outcome: RecalcOutcome.rapidLoss,
        message:
            "You've changed more than expected this week. Before we update your targets, make sure you've been eating enough. Rapid changes can sometimes indicate insufficient nutrition.",
      );
    }

    // ── All rules passed — calculate new targets ───────────────────────────
    final userWithNewWeight = user.copyWith(weightKg: currentAvg);
    final plan = TDEECalculator.calculateAll(
      user: userWithNewWeight,
      weeklyPacePercent: user.weeklyPacePercent ?? 0.75,
    );

    // Apply safety floors
    final floor = _floor(user.biologicalSex);
    final minByDeficit = _minCalories(plan.tdee);
    final safeTarget = plan.targetCalories
        .clamp(floor > minByDeficit ? floor : minByDeficit, double.infinity);

    final calDiff = (safeTarget - user.targetCalories).abs();

    // Classify change size
    RecalcOutcome outcome;
    double phasedAdj = 0;
    double appliedTarget = safeTarget;

    if (calDiff <= 100) {
      outcome = RecalcOutcome.smallChange;
    } else if (calDiff <= 250) {
      outcome = RecalcOutcome.mediumChange;
    } else {
      outcome = RecalcOutcome.largeChange;
      // Phase in: apply half now, store half for next week
      phasedAdj = calDiff / 2;
      final direction = safeTarget > user.targetCalories ? 1 : -1;
      appliedTarget = user.targetCalories + (phasedAdj * direction);
      appliedTarget = appliedTarget.clamp(floor, double.infinity);
    }

    final details = RecalcDetails(
      currentWeeklyAvg: currentAvg,
      previousWeeklyAvg: previousAvg,
      delta: delta,
      newTargetCalories: appliedTarget,
      oldTargetCalories: user.targetCalories,
      newTdee: plan.tdee,
      newProteinG: plan.proteinG,
      newCarbsG: plan.carbsG,
      newFatG: plan.fatG,
      calorieDifference: calDiff,
      phasedAdjustment: phasedAdj,
    );

    final String message = switch (outcome) {
      RecalcOutcome.smallChange =>
        "Your targets have been fine-tuned based on this week's weigh-ins.",
      RecalcOutcome.mediumChange =>
        "Your weight has shifted this week. Here's how your targets would update.",
      RecalcOutcome.largeChange =>
        "Your weight has changed noticeably. We're gradually adjusting your targets — applying half the change now to help your body and habits adjust smoothly.",
      _ => '',
    };

    return WeeklyRecalcResult(
      outcome: outcome,
      message: message,
      details: details,
    );
  }

  // ---------------------------------------------------------------------------
  // Situation 5 — Actual vs Predicted Divergence
  // ---------------------------------------------------------------------------
  Future<AdjustmentSituation?> _checkSituation5(
      UserModel user, String userId) async {
    // Skip if checked in last 21 days
    if (user.lastDivergenceCheck != null) {
      final last = DateTime.tryParse(user.lastDivergenceCheck!);
      if (last != null &&
          DateTime.now().difference(last).inDays < 21) return null;
    }

    // Need 21 days since start
    if (user.goalStartDate == null) return null;
    final start = DateTime.tryParse(user.goalStartDate!);
    if (start == null) return null;
    final daysSinceStart = DateTime.now().difference(start).inDays;
    if (daysSinceStart < 21) return null;

    // Need ≥10 weight entries in last 21 days
    final weights = await _weightSvc.getRecentWeights(userId, days: 21);
    if (_distinctDays(weights) < 10) return null;

    // Need ≥14 food log days in last 21 days
    final foodDays = await _weightSvc.countDistinctFoodLogDays(userId, days: 21);
    if (foodDays < 14) return null;

    // Calculate divergence
    final deficit = user.dailyDeficitSurplus ?? 0;
    final expectedChange = deficit * daysSinceStart / 7700;
    // expected in kg: negative deficit → weight loss → expectedChange negative
    final expectedWeight = user.weightKg - expectedChange.abs() *
        (user.goal == 'lose' ? 1 : -1);

    final actualAvg = _weightSvc.calculateWeeklyAverage(
        weights.where((e) {
          return e.loggedAt.isAfter(
              DateTime.now().subtract(const Duration(days: 7)));
        }).toList());

    final absoluteDiff = (expectedWeight - actualAvg).abs();
    final totalExpectedChange = expectedChange.abs();
    final rateDiffPct = totalExpectedChange > 0
        ? absoluteDiff / totalExpectedChange * 100
        : 0.0;

    final threshold = user.lowPressureMode ? 25.0 : 15.0;
    if (rateDiffPct < threshold || absoluteDiff < 0.5) return null;

    return AdjustmentSituation(
      type: SituationType.divergence,
      divergenceResult: DivergenceResult(
        hasDivergence: true,
        expectedChangeKg: expectedChange,
        actualChangeKg: user.weightKg - actualAvg,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Frequency limiter — max 1 card shown at a time, priority enforced
  // Priority: Sit4 > Sit1 > Sit5 > Sit2 > Sit3
  // ---------------------------------------------------------------------------
  List<AdjustmentSituation> applyFrequencyLimit(
      List<AdjustmentSituation> all) {
    const priority = [
      SituationType.weeklyRecalc,
      SituationType.loggingGap,
      SituationType.divergence,
      SituationType.goalDateApproaching,
      SituationType.weightUpdatePrompt,
    ];

    for (final p in priority) {
      final match = all.where((s) => s.type == p).firstOrNull;
      if (match != null) return [match];
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Apply new targets after confirmation (Option smallChange / mediumChange)
  // ---------------------------------------------------------------------------
  Future<void> applyNewTargets({
    required String userId,
    required RecalcDetails details,
    required double phasedAdjustmentToStore, // 0 unless large change
  }) async {
    try {
      final today = _dateStr(DateTime.now());
      await _client.from('users').update({
        'target_calories': details.newTargetCalories.round(),
        'protein_g': details.newProteinG.round(),
        'carbs_g': details.newCarbsG.round(),
        'fat_g': details.newFatG.round(),
        'tdee': details.newTdee.round(),
        'weight_kg': details.currentWeeklyAvg,
        'last_weekly_recalc_date': today,
        'previous_weekly_weight': details.currentWeeklyAvg,
        'pending_target_adjustment': phasedAdjustmentToStore,
      }).eq('id', userId);

      debugPrint('[AUTOADJ] Targets updated: '
          '${details.oldTargetCalories.round()} → '
          '${details.newTargetCalories.round()} kcal');
    } catch (e) {
      debugPrint('[AUTOADJ] applyNewTargets error: $e');
      rethrow;
    }
  }

  Future<void> markGoalDateReminderShown(String userId) async {
    try {
      await _client
          .from('users')
          .update({'goal_date_reminder_shown': true}).eq('id', userId);
    } catch (e) {
      debugPrint('[AUTOADJ] markGoalDateReminderShown error: $e');
    }
  }

  Future<void> applyGoalOption(
      String userId, String option, GoalProgressSummary progress) async {
    try {
      if (option == 'extend_date') {
        await _client
            .from('users')
            .update({'goal_end_date': progress.suggestedNewGoalDate})
            .eq('id', userId);
      } else if (option == 'adjust_goal') {
        await _client.from('users').update({
          'target_weight_kg':
              double.parse(progress.suggestedNewTargetWeight.toStringAsFixed(1)),
        }).eq('id', userId);
      }
      await markGoalDateReminderShown(userId);
    } catch (e) {
      debugPrint('[AUTOADJ] applyGoalOption error: $e');
      rethrow;
    }
  }

  Future<void> updateLastSituation3Prompt(String userId) async {
    try {
      await _client.from('users').update(
          {'last_situation3_prompt': _dateStr(DateTime.now())}).eq('id', userId);
    } catch (e) {
      debugPrint('[AUTOADJ] updateLastSituation3Prompt error: $e');
    }
  }

  Future<void> updateLastDivergenceCheck(String userId) async {
    try {
      await _client.from('users').update(
          {'last_divergence_check': _dateStr(DateTime.now())}).eq('id', userId);
    } catch (e) {
      debugPrint('[AUTOADJ] updateLastDivergenceCheck error: $e');
    }
  }

  Future<void> markWeeklyRecalcSkipped(String userId) async {
    try {
      await _client.from('users').update(
          {'last_weekly_recalc_date': _dateStr(DateTime.now())}).eq('id', userId);
    } catch (e) {
      debugPrint('[AUTOADJ] markWeeklyRecalcSkipped error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  int _distinctDays(List<WeightLog> entries) {
    return entries.map((e) => _dateStr(e.loggedAt)).toSet().length;
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}
