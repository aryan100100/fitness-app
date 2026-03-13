// [HEALTH APP] — Dashboard Screen (Feature 3)
// Main daily view: greeting, calorie ring, macros, meal sections, emergency button.
// Powered by DashboardProvider (ChangeNotifier).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auto_adjustment_service.dart';
import '../../core/services/low_motivation_service.dart';
import '../../core/services/streak_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_card.dart';
import '../emergency/emergency_button_sheet.dart';
import '../low_motivation/low_motivation_sheet.dart';
import '../weight_log/weight_log_screen.dart';
import '../streaks/streak_widget.dart';
import '../streaks/streak_milestone_card.dart';
import '../streaks/streak_reset_card.dart';
import 'dashboard_provider.dart';
import 'widgets/adjustment_card.dart';
import 'widgets/calorie_ring.dart';
import 'widgets/divergence_diagnostic_card.dart';
import 'widgets/goal_progress_card.dart';
import 'widgets/macro_bar_card.dart';
import 'widgets/meal_section.dart';
import 'widgets/tdee_confidence_card.dart';
import 'widgets/weekly_recalc_card.dart';
import 'widgets/weekly_summary_bar.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showRecalibrationBanner = false;
  bool _showNudgeBanner = false;
  bool _showAdjustedBanner = false;
  AdjustmentSituation? _activeSituation;

  int _shownMilestone = 0;
  String? _shownResetDate;

  @override
  void initState() {
    super.initState();
    _loadLocalFlags();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().refresh(widget.user).then((_) {
        _checkNudge();
        _checkSituations();
      });
    });
  }

  Future<void> _loadLocalFlags() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _shownMilestone = prefs.getInt('last_milestone_${widget.user.id}') ?? 0;
        _shownResetDate = prefs.getString('streak_reset_${widget.user.id}');
      });
    }
  }

  void _checkSituations() {
    AutoAdjustmentService.instance
        .checkAllSituations(widget.user)
        .then((situations) {
      if (mounted && situations.isNotEmpty) {
        setState(() => _activeSituation = situations.first);
      }
    });
  }

  void _checkNudge() {
    final hour = DateTime.now().hour;
    final summary = context.read<DashboardProvider>().summary;
    if (hour >= 14 && summary != null && summary.totalCalories == 0) {
      if (mounted) setState(() => _showNudgeBanner = true);
    }
  }

  void _navigateToWeightLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeightLogScreen(user: widget.user, showBackButton: true),
      ),
    );
  }

  Widget _buildSituationCard(
      AdjustmentSituation situation, DashboardProvider provider) {
    void dismiss() => setState(() => _activeSituation = null);

    switch (situation.type) {
      case SituationType.loggingGap:
        return AdjustmentCard(
          borderColor: const Color(0xFFFFB300),
          emoji: '👋',
          title: 'Welcome back',
          body: "You've had a short break from logging — that's completely normal. "
              "A quick weight check helps us keep your plan accurate.",
          onDismiss: dismiss,
          actions: [
            CardActionButton(
              label: 'Log my weight',
              onTap: () {
                dismiss();
                _navigateToWeightLog();
              },
            ),
            const SizedBox(height: 6),
            CardActionButton(
                label: 'Skip for now', onTap: dismiss, isPrimary: false),
          ],
        );

      case SituationType.goalDateApproaching:
        return GoalProgressCard(
          progress: situation.goalProgress!,
          onDismiss: dismiss,
          onApply: (option) async {
            await AutoAdjustmentService.instance
                .applyGoalOption(widget.user.id ?? '', option, situation.goalProgress!);
            provider.refresh(widget.user);
          },
        );

      case SituationType.weightUpdatePrompt:
        return AdjustmentCard(
          borderColor: const Color(0xFF4CAF50),
          emoji: '🎯',
          title: 'Great consistency!',
          body: "You've been logging regularly. Updating your weight helps us keep your plan accurate "
              "— even 1–2 kg of change affects your ideal targets.",
          onDismiss: dismiss,
          actions: [
            CardActionButton(
              label: 'Update my weight',
              onTap: () {
                AutoAdjustmentService.instance
                    .updateLastSituation3Prompt(widget.user.id ?? '');
                dismiss();
                _navigateToWeightLog();
              },
            ),
            const SizedBox(height: 6),
            CardActionButton(
                label: 'Remind me later', onTap: dismiss, isPrimary: false),
          ],
        );

      case SituationType.weeklyRecalc:
        final result = situation.recalcResult!;
        return WeeklyRecalcCard(
          result: result,
          onDismiss: dismiss,
          onApply: result.details != null
              ? () async {
                  await AutoAdjustmentService.instance.applyNewTargets(
                    userId: widget.user.id ?? '',
                    details: result.details!,
                    phasedAdjustmentToStore:
                        result.outcome == RecalcOutcome.largeChange
                            ? result.details!.phasedAdjustment
                            : 0,
                  );
                  provider.refresh(widget.user);
                }
              : null,
          onSkip: () => AutoAdjustmentService.instance
              .markWeeklyRecalcSkipped(widget.user.id ?? ''),
        );

      case SituationType.divergence:
        return DivergenceDiagnosticCard(
          result: situation.divergenceResult!,
          isFemale: widget.user.biologicalSex == 'female',
          onDismiss: dismiss,
          onRequestRecalibration: () {
            // Feature 4 recalibration flow — surfaced from banner
            AutoAdjustmentService.instance
                .updateLastDivergenceCheck(widget.user.id ?? '');
          },
          onSnooze: () {
            AutoAdjustmentService.instance
                .updateLastDivergenceCheck(widget.user.id ?? '');
          },
        );
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final name = widget.user.name.split(' ').first;
    if (hour < 12) return 'Good morning, $name';
    if (hour < 17) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  String get _todayDate {
    return DateFormat('EEEE, d MMMM').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<DashboardProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.summary == null) {
              return _ShimmerSkeleton();
            }
            final s = provider.summary;
            return RefreshIndicator(
              color: AppColors.primaryAccent,
              backgroundColor: AppColors.cardSurface,
              onRefresh: () => provider.refresh(widget.user),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.horizontalPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),

                        // ── Top bar ──────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_greeting,
                                      style: AppTextStyles.headingMedium
                                          .copyWith(fontSize: 20)),
                                  const SizedBox(height: 2),
                                  Text(_todayDate,
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            // Avatar
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.subtleBorder,
                                    width: 1.0),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.person,
                                      color: AppColors.primaryAccent),
                                  Center(
                                    child: Text(
                                      widget.user.name.isNotEmpty
                                          ? widget.user.name[0].toUpperCase()
                                          : '?',
                                      style: AppTextStyles.body.copyWith(
                                          color: AppColors.primaryText,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (provider.clinicalFlag == LowMotivationFlag.clinical)
                          _ClinicalFlagCard(
                            user: widget.user,
                            onDismiss: () {
                              context.read<DashboardProvider>().refresh(widget.user);
                            },
                          )
                        else if (_activeSituation != null)
                          _buildSituationCard(_activeSituation!, provider),

                        const SizedBox(height: 12),

                        // ── Streak badge & Cards ─────────────────────────────
                        if (provider.streakModel != null && !provider.hideStreakCounter) ...[
                          StreakWidget(
                            streak: provider.streakModel!,
                            last7Days: provider.last7Days,
                          ),
                          
                          // Milestone celebration
                          if (provider.streakModel!.currentStreak > 0 &&
                              StreakService.instance.shouldShowMilestone(provider.streakModel!.currentStreak) &&
                              provider.streakModel!.currentStreak > _shownMilestone)
                            StreakMilestoneCard(
                              streakDays: provider.streakModel!.currentStreak,
                              onDismiss: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setInt('last_milestone_${widget.user.id}', provider.streakModel!.currentStreak);
                                setState(() => _shownMilestone = provider.streakModel!.currentStreak);
                              },
                            ),

                          // Streak Reset Fresh Start
                          if (provider.streakModel!.currentStreak == 0 &&
                              provider.streakModel!.longestStreak > 0 &&
                              _shownResetDate != DateFormat('yyyy-MM-dd').format(DateTime.now()))
                            StreakResetCard(
                              onDismiss: () async {
                                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('streak_reset_${widget.user.id}', today);
                                setState(() => _shownResetDate = today);
                              },
                            ),
                        ],

                        const SizedBox(height: 16),

                        // ── Low weight warning (BMI < 18.5 + lose) ───────────
                        if (s != null &&
                            s.bmi < 18.5 &&
                            s.goal == 'lose')
                          _LowWeightBanner(),

                        // ── 2pm nudge banner ─────────────────────────────────
                        if (_showNudgeBanner)
                          _NudgeBanner(
                              onDismiss: () => setState(
                                  () => _showNudgeBanner = false)),

                        // ── Recalibration banner ─────────────────────────────
                        if (_showRecalibrationBanner && s != null)
                          _RecalibrationBanner(
                            newTarget: s.recalibratedTargetCalories ??
                                s.targetCalories,
                            onDismiss: () => setState(
                                () => _showRecalibrationBanner = false),
                          ),

                        // ── Plan adjusted banner ──────────────────────────────
                        if (_showAdjustedBanner)
                          _PlanAdjustedBanner(
                            onDismiss: () =>
                                setState(() => _showAdjustedBanner = false),
                          ),

                        // ── Auto-adjustment situation card (Feature 7) ────────
                        if (_activeSituation != null)
                          _buildSituationCard(_activeSituation!, provider),

                        // ── Calorie ring card ────────────────────────────────
                        if (s != null) ...[
                          AppCard(
                            child: Column(
                              children: [
                                CalorieRingWidget(
                                  consumed: s.totalCalories,
                                  target: s.targetCalories,
                                ),
                              ],
                            ),
                          ),

                          // Overage soft message
                          if (s.isOver && !s.isMinimumViableDay) ...[
                            const SizedBox(height: 8),
                            _OverageMessage(),
                          ],

                          const SizedBox(height: 12),
                          Center(child: _LowMotivationButton(user: widget.user)),
                          const SizedBox(height: 12),

                          // ── Macro bar card ──────────────────────────────
                          if (!s.isMinimumViableDay) ...[
                            MacroBarCard(
                              protein: s.totalProtein,
                              carbs: s.totalCarbs,
                              fat: s.totalFat,
                              fibre: s.totalFibre,
                              targetProtein: s.targetProtein,
                              targetCarbs: s.targetCarbs,
                              targetFat: s.targetFat,
                              targetFibre: s.targetFibre,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── TDEE confidence card ────────────────────────
                          TDEEConfidenceCard(
                            confidence: s.tdeeConfidence,
                            daysLogged: s.daysLoggedForCalibration,
                          ),

                          const SizedBox(height: 20),
                        ],

                        // ── Meal sections ────────────────────────────────────
                        Text('Today\'s Meals',
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),

                        for (final meal in [
                          'breakfast',
                          'lunch',
                          'dinner',
                          'snack'
                        ])
                          MealSection(
                            mealType: meal,
                            logs: provider.logsForMeal(meal),
                            onAddTap: () => _navigateToFoodLog(
                                context, meal, provider),
                          ),

                        // ── Weekly summary ───────────────────────────────────
                        if (s != null) ...[
                          const SizedBox(height: 4),
                          WeeklySummaryBar(
                            weeklyLogged: s.weeklyCaloriesLogged,
                            weeklyTarget: s.weeklyCaloriesTarget,
                            daysLogged: s.weeklyDaysLogged,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Emergency button ─────────────────────────────────
                        _EmergencyButton(
                          isOver: s != null &&
                              s.totalCalories > s.targetCalories + 200,
                          onSheetResult: (adjusted) {
                            if (adjusted == true) {
                              setState(
                                  () => _showAdjustedBanner = true);
                              provider.refresh(widget.user);
                            }
                          },
                          user: widget.user,
                          summary: s,
                        ),

                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateToFoodLog(
      BuildContext context, String mealType, DashboardProvider provider) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: _FoodLogPlaceholder(
              mealType: mealType, user: widget.user),
        ),
      ),
    )
        .then((_) {
      provider.refresh(widget.user);
    });
  }
}

// ---------------------------------------------------------------------------
// Streak badge
// ---------------------------------------------------------------------------
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.primaryAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_outlined, size: 16, color: AppColors.primaryAccent),
            const SizedBox(width: 4),
            Text(
              '$streak day streak',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        const Icon(Icons.eco_outlined, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: 6),
        Text('Log today to start your streak',
            style: AppTextStyles.caption),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overage soft message (non-punitive)
// ---------------------------------------------------------------------------
class _OverageMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.favorite_outline, color: AppColors.primaryAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Over today? That\'s okay — one day doesn\'t define your progress. Tap Emergency below if you\'d like to smooth this out.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Low BMI warning
// ---------------------------------------------------------------------------
class _LowWeightBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your current BMI suggests you may already be at a low weight. We recommend speaking with a doctor before pursuing further weight loss.',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2pm nudge banner
// ---------------------------------------------------------------------------
class _NudgeBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _NudgeBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Haven\'t logged today yet? Even a rough estimate helps — it all adds up.',
              style: AppTextStyles.caption,
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 16, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recalibration banner
// ---------------------------------------------------------------------------
class _RecalibrationBanner extends StatelessWidget {
  final double newTarget;
  final VoidCallback onDismiss;
  const _RecalibrationBanner(
      {required this.newTarget, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.cardSurface,
            title: Text('Target Refined',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.bold)),
            content: Text(
              'Based on your real progress data over the last 14 days, we\'ve refined your calorie target to ${newTarget.round()} kcal/day. Your formula estimate has been blended with your actual outcomes for a more accurate target.',
              style: AppTextStyles.bodySecondary,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Got it',
                      style: AppTextStyles.captionAccent)),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primaryAccent.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_outlined, color: AppColors.primaryAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your calorie target has been refined based on your real progress. New target: ${newTarget.round()} kcal/day',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryAccent),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  size: 16, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency button — pulses amber when user is 200+ kcal over target
// ---------------------------------------------------------------------------
class _EmergencyButton extends StatefulWidget {
  final bool isOver;
  final ValueChanged<bool?> onSheetResult;
  final UserModel user;
  final dynamic summary; // DashboardSummary — nullable

  const _EmergencyButton({
    required this.isOver,
    required this.onSheetResult,
    required this.user,
    required this.summary,
  });

  @override
  State<_EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<_EmergencyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  static const _amber = Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _opacity = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (widget.isOver) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_EmergencyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOver && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isOver && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openSheet() {
    HapticFeedback.mediumImpact();
    if (widget.summary == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmergencyButtonSheet(
        user: widget.user,
        summary: widget.summary,
      ),
    ).then(widget.onSheetResult);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isOver ? _amber : AppColors.destructive;
    final bgColor = widget.isOver
        ? _amber.withOpacity(0.07)
        : const Color(0x08FF5252);
    final textColor = widget.isOver ? _amber : AppColors.destructive;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, child) => Opacity(
        opacity: widget.isOver ? _opacity.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: _openSheet,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tough Day? Emergency Adjust',
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan adjusted banner — shown after successful adjustment
// ---------------------------------------------------------------------------
class _PlanAdjustedBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _PlanAdjustedBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Plan adjusted — you\'re back on track',
              style: TextStyle(color: Color(0xFF81C784), fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 16, color: Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer skeleton while data loads
// ---------------------------------------------------------------------------
class _ShimmerSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cardSurface,
      highlightColor: AppColors.elevatedCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontalPadding, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Container(height: 22, width: 200,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 8),
            Container(height: 14, width: 140,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 24),
            // Ring placeholder
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(height: 24),
            // Macro bar placeholder
            Container(height: 100, decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 12),
            Container(height: 60, decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Temporary food log placeholder — replaced in Phase 3
// ---------------------------------------------------------------------------
class _FoodLogPlaceholder extends StatelessWidget {
  final String mealType;
  final UserModel user;
  const _FoodLogPlaceholder(
      {required this.mealType, required this.user});

  @override
  Widget build(BuildContext context) {
    final label = switch (mealType) {
      'breakfast' => 'Breakfast',
      'lunch'     => 'Lunch',
      'dinner'    => 'Dinner',
      _           => 'Snacks',
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Log $label', style: AppTextStyles.body),
        leading: const BackButton(color: AppColors.primaryText),
      ),
      body: Center(
        child: Text(
          'Food Log — coming next in Phase 3',
          style: AppTextStyles.bodySecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Low Motivation Button
// ---------------------------------------------------------------------------
class _LowMotivationButton extends StatelessWidget {
  final UserModel user;
  const _LowMotivationButton({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => LowMotivationSheet(user: user),
        ).then((changed) {
          if (changed == true) {
            context.read<DashboardProvider>().refresh(user);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.battery_1_bar_rounded, size: 16, color: AppColors.secondaryText),
            const SizedBox(width: 8),
            Text('Low Motivation?', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimum Viable Day Header
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Clinical Flag Card
// ---------------------------------------------------------------------------
class _ClinicalFlagCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDismiss;

  const _ClinicalFlagCard({
    required this.user,
    required this.onDismiss,
  });

  Future<void> _launchSupportUrl() async {
    const urlStr = 'https://www.iCall.iitb.ac.in';
    final url = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _handleDismiss() async {
    await LowMotivationService.instance.markClinicalFlagShown(user.id ?? '');
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "We've noticed you've been having a lot of tough days. 💙",
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _handleDismiss,
                child: const Icon(Icons.close, size: 20, color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "This app can help with nutrition, but it can't replace human support. If things feel really hard right now, please consider talking to someone.",
            style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _launchSupportUrl();
                _handleDismiss();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Find support',
                style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFFFFB300),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
