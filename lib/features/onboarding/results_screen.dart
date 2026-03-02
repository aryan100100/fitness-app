// [HEALTH APP] — Onboarding Results Screen
// Animated entry, counting numbers, macro ring visuals, Supabase save.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
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
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Counting animation values
  double _tdeeDisplay = 0;
  double _targetDisplay = 0;
  double _proteinDisplay = 0;
  double _carbsDisplay = 0;
  double _fatDisplay = 0;

  Timer? _countTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(_fadeAnim);
    _animCtrl.forward();

    // Animate numbers counting up over 1.2s
    _startCountingAnimation();
  }

  void _startCountingAnimation() {
    final result = widget.controller.result;
    if (result == null) return;

    const steps = 60;
    const duration = Duration(milliseconds: 1200);
    int step = 0;

    _countTimer = Timer.periodic(
      Duration(milliseconds: duration.inMilliseconds ~/ steps),
      (timer) {
        if (!mounted) { timer.cancel(); return; }
        step++;
        final progress = step / steps;
        setState(() {
          _tdeeDisplay = result.tdee * progress;
          _targetDisplay = result.targetCalories * progress;
          _proteinDisplay = result.macros.protein * progress;
          _carbsDisplay = result.macros.carbs * progress;
          _fatDisplay = result.macros.fat * progress;
        });
        if (step >= steps) timer.cancel();
      },
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  Future<void> _onLetsStart() async {
    final success = await widget.controller.saveToSupabase();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final result = ctrl.result;
    if (result == null) return const SizedBox.shrink();

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

                  // --- Headline ---
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                            text: "Here's your plan, ",
                            style: AppTextStyles.headingLarge),
                        TextSpan(
                          text: '${ctrl.name} 🎯',
                          style: AppTextStyles.headingLarge.copyWith(
                              color: AppColors.primaryAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Based on your profile — personalised for you.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 32),

                  // --- Maintenance calories ---
                  _StatCard(
                    label: 'Maintenance Calories',
                    value: _tdeeDisplay.toStringAsFixed(0),
                    unit: 'kcal / day',
                    subtitle: 'What your body burns doing nothing extra',
                    icon: Icons.local_fire_department_outlined,
                    color: AppColors.secondaryAccent,
                  ),
                  const SizedBox(height: AppSpacing.cardSpacing),

                  // --- Target calories ---
                  _StatCard(
                    label: _goalLabel(ctrl.goal),
                    value: _targetDisplay.toStringAsFixed(0),
                    unit: 'kcal / day',
                    subtitle: _goalSubtitle(ctrl.goal),
                    icon: Icons.track_changes,
                    color: AppColors.primaryAccent,
                    highlighted: true,
                  ),
                  const SizedBox(height: AppSpacing.cardSpacing),

                  // --- Macros ---
                  _MacroRow(
                    proteinG: _proteinDisplay,
                    carbsG: _carbsDisplay,
                    fatG: _fatDisplay,
                    totalProtein: result.macros.protein,
                    totalCarbs: result.macros.carbs,
                    totalFat: result.macros.fat,
                  ),
                  const SizedBox(height: 16),

                  // --- Fibre note ---
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco_outlined,
                            color: AppColors.secondaryAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Daily fibre target: ${result.macros.fiber.toStringAsFixed(0)}g',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // --- Save & go ---
                  ListenableBuilder(
                    listenable: ctrl,
                    builder: (context, child) {
                      return Column(
                        children: [
                          if (ctrl.saveError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                ctrl.saveError!,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.destructive),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          PrimaryButton(
                            label: "Let's Start 🚀",
                            isLoading: ctrl.isSaving,
                            onTap: ctrl.isSaving ? null : _onLetsStart,
                          ),
                        ],
                      );
                    },
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

  String _goalLabel(String goal) {
    switch (goal) {
      case 'lose': return 'Your Weight Loss Target';
      case 'gain': return 'Your Weight Gain Target';
      default:     return 'Your Maintenance Target';
    }
  }

  String _goalSubtitle(String goal) {
    switch (goal) {
      case 'lose': return '400 kcal deficit — sustainable and effective';
      case 'gain': return '300 kcal surplus — clean lean bulk';
      default:     return 'At maintenance — stay exactly where you are';
    }
  }
}

// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool highlighted;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.08)
            : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: highlighted ? color : AppColors.divider,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: value,
                      style: AppTextStyles.statsNumber.copyWith(
                          fontSize: 28, color: color),
                    ),
                    TextSpan(
                        text: '  $unit',
                        style: AppTextStyles.bodySecondary),
                  ]),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const _MacroRow({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Macro Targets', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          _MacroBar(
            label: 'Protein',
            grams: proteinG,
            total: totalProtein,
            color: AppColors.proteinBar,
          ),
          const SizedBox(height: 12),
          _MacroBar(
            label: 'Carbs',
            grams: carbsG,
            total: totalCarbs,
            color: AppColors.carbBar,
          ),
          const SizedBox(height: 12),
          _MacroBar(
            label: 'Fat',
            grams: fatG,
            total: totalFat,
            color: AppColors.fatBar,
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double grams;
  final double total;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.grams,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (grams / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(
              '${total.toStringAsFixed(0)}g',
              style:
                  AppTextStyles.caption.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
