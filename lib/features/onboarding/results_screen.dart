// [HEALTH APP] — Results Screen (Feature 2 Rewrite)
// Shows: TDEE range, target calories, macros with dots, timeline.
// All numbers animate counting up from 0 over 1.2s on entry.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_helpers.dart';
import '../../widgets/primary_button.dart';
import '../dashboard/dashboard_screen.dart';
import 'onboarding_controller.dart';

class ResultsScreen extends StatefulWidget {
  final OnboardingController controller;
  const ResultsScreen({super.key, required this.controller});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Counting animation values
  double _tdeeLow = 0;
  double _tdeeHigh = 0;
  double _tdeeBest = 0;
  double _targetCal = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fat = 0;

  Timer? _countTimer;

  @override
  void initState() {
    super.initState();

    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(_fadeAnim);

    _startCounting();
  }

  void _startCounting() {
    final plan = widget.controller.nutritionPlan;
    if (plan == null) return;

    const steps = 60;
    int step = 0;
    _countTimer = Timer.periodic(
      const Duration(milliseconds: 20), // 1200ms / 60 steps
      (timer) {
        if (!mounted) { timer.cancel(); return; }
        step++;
        final t = step / steps;
        setState(() {
          _tdeeLow    = plan.tdeeLow    * t;
          _tdeeHigh   = plan.tdeeHigh   * t;
          _tdeeBest   = plan.tdee       * t;
          _targetCal  = plan.targetCalories * t;
          _protein    = plan.proteinG   * t;
          _carbs      = plan.carbsG     * t;
          _fat        = plan.fatG       * t;
        });
        if (step >= steps) timer.cancel();
      },
    );
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  Future<void> _onLetsStart() async {
    final success = await widget.controller.saveToSupabase();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (ctx) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final plan = ctrl.nutritionPlan;
    if (plan == null) return const SizedBox.shrink();
    final isGoalWithTimeline =
        ctrl.goal == 'lose' || ctrl.goal == 'gain';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Headline
                  Text('Your personalised plan is ready 🎯',
                      style: AppTextStyles.headingLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Based on your profile, here\'s what we recommend.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 32),

                  // Card 1 — Maintenance calories (range)
                  _ResultCard(
                    label: 'Maintenance Calories',
                    icon: Icons.local_fire_department_outlined,
                    iconColor: AppColors.secondaryAccent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_tdeeLow.toStringAsFixed(0)} – ${_tdeeHigh.toStringAsFixed(0)} kcal / day',
                          style: AppTextStyles.statsNumber.copyWith(
                              fontSize: 22,
                              color: AppColors.secondaryAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Best estimate: ${_tdeeBest.toStringAsFixed(0)} kcal',
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Typically accurate within 10% for most people. We\'ll fine-tune this as you track.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.cardSpacing),

                  // Card 2 — Daily target
                  _ResultCard(
                    label: 'Your Daily Calorie Target',
                    icon: Icons.track_changes,
                    iconColor: AppColors.primaryAccent,
                    highlighted: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_targetCal.toStringAsFixed(0)} kcal',
                          style: AppTextStyles.statsNumber.copyWith(
                              fontSize: 32,
                              color: AppColors.primaryAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(_goalDescription(ctrl.goal),
                            style: AppTextStyles.caption),
                        if (plan.calorieFloorApplied) ...[
                          const SizedBox(height: 6),
                          Text(
                            '⚠️ Capped at safe minimum — consider a gentler pace.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.destructive),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.cardSpacing),

                  // Card 3 — Macros
                  _ResultCard(
                    label: 'Your Daily Macros',
                    icon: Icons.pie_chart_outline,
                    iconColor: AppColors.primaryAccent,
                    child: Column(
                      children: [
                        _MacroRow(
                          dot: AppColors.proteinBar,
                          name: 'Protein',
                          grams: _protein,
                        ),
                        const SizedBox(height: 12),
                        _MacroRow(
                          dot: AppColors.carbBar,
                          name: 'Carbs',
                          grams: _carbs,
                        ),
                        const SizedBox(height: 12),
                        _MacroRow(
                          dot: AppColors.fatBar,
                          name: 'Fat',
                          grams: _fat,
                        ),
                        if (plan.carbWarning) ...[
                          const SizedBox(height: 10),
                          Text(
                            '⚠️ Carbs are very low — consider a gentler pace.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.destructive),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Card 4 — Timeline (hide for maintain)
                  if (isGoalWithTimeline && plan.goalEndDate != null) ...[
                    const SizedBox(height: AppSpacing.cardSpacing),
                    _ResultCard(
                      label: 'Your Timeline',
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.secondaryAccent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated to reach your goal by:',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateHelpers.formatDate(plan.goalEndDate!),
                            style: AppTextStyles.statsNumber.copyWith(
                                fontSize: 22,
                                color: AppColors.secondaryAccent),
                          ),
                          const SizedBox(height: 4),
                          Builder(builder: (context) {
                            final (w, d) = DateHelpers.weeksAndDaysUntil(
                                plan.goalEndDate!);
                            return Text('That\'s $w weeks from today',
                                style: AppTextStyles.caption);
                          }),
                        ],
                      ),
                    ),
                  ],

                  // Disclaimer
                  const SizedBox(height: 24),
                  Text(
                    'These are starting estimates based on established scientific formulas. Your actual needs may vary. The app will help you adjust based on your real progress over time.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // CTA
                  ListenableBuilder(
                    listenable: ctrl,
                    builder: (context, child) => Column(
                      children: [
                        if (ctrl.saveError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              ctrl.saveError!,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.destructive),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        PrimaryButton(
                          label: "Let's Start →",
                          isLoading: ctrl.isSaving,
                          onTap: ctrl.isSaving ? null : _onLetsStart,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _goalDescription(String goal) {
    switch (goal) {
      case 'lose': return 'For losing weight at a sustainable pace';
      case 'gain': return 'For building muscle with a lean bulk';
      default:     return 'To maintain your current weight';
    }
  }
}

// ---------------------------------------------------------------------------
// Shared result card
// ---------------------------------------------------------------------------
class _ResultCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final bool highlighted;

  const _ResultCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted
            ? iconColor.withValues(alpha: 0.07)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: highlighted ? iconColor : AppColors.divider,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro row with coloured dot
// ---------------------------------------------------------------------------
class _MacroRow extends StatelessWidget {
  final Color dot;
  final String name;
  final double grams;

  const _MacroRow({
    required this.dot,
    required this.name,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: AppTextStyles.body),
        ),
        Text(
          '${grams.toStringAsFixed(0)}g',
          style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: dot),
        ),
      ],
    );
  }
}
