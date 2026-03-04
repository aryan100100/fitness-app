// [HEALTH APP] — Goal Pace Slider Screen
// Feature 2: Dynamic calorie target via % bodyweight/week slider.
// All 4 stat cards update in real time on every slider tick.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../core/utils/date_helpers.dart';
import '../../widgets/primary_button.dart';
import 'onboarding_controller.dart';
import 'results_screen.dart';

class GoalPaceScreen extends StatefulWidget {
  final OnboardingController controller;
  const GoalPaceScreen({super.key, required this.controller});

  @override
  State<GoalPaceScreen> createState() => _GoalPaceScreenState();
}

class _GoalPaceScreenState extends State<GoalPaceScreen>
    with SingleTickerProviderStateMixin {
  late double _pace;
  bool _wasInCautionZone = false;

  // Derived values — recalculated on every slider tick
  double _weeklyChange = 0;
  double _dailyAdjustment = 0;
  double _targetCalories = 0;
  bool _floorApplied = false;
  DateTime? _goalEndDate;

  late AnimationController _entryAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  OnboardingController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _pace = ctrl.goal == 'gain' ? 0.25 : 0.75;
    _recalculate(_pace);

    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(_fadeAnim);
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    super.dispose();
  }

  void _recalculate(double pace) {
    final weeklyChange = TDEECalculator.calculateWeeklyWeightChange(
      weightKg: ctrl.weightKg,
      pacePercent: pace,
    );
    final dailyAdj = TDEECalculator.calculateDailyCalorieAdjustment(weeklyChange);

    // Temporary UserModel-like inputs for calculateTargetCalories
    final tdeeResult = TDEECalculator.calculateTargetCalories(
      tdee: ctrl.nutritionPlan?.tdee ??
          TDEECalculator.applyBodyFatModifier(
            TDEECalculator.calculateTDEE(
              TDEECalculator.calculateBMR(
                weightKg: ctrl.weightKg,
                heightCm: ctrl.heightCm,
                age: ctrl.age,
                biologicalSex: ctrl.biologicalSex,
              ),
              ctrl.activityLevel.isEmpty ? 'sedentary' : ctrl.activityLevel,
            ),
            ctrl.bodyFatRange,
          ),
      dailyCalorieAdjustment: dailyAdj,
      goal: ctrl.goal,
      biologicalSex: ctrl.biologicalSex,
    );

    final goalEndDate = TDEECalculator.calculateGoalEndDate(
      currentWeight: ctrl.weightKg,
      targetWeight: ctrl.targetWeightKg,
      dailyCalorieAdjustment: dailyAdj,
    );

    setState(() {
      _weeklyChange = weeklyChange;
      _dailyAdjustment = dailyAdj;
      _targetCalories = tdeeResult.calories;
      _floorApplied = tdeeResult.floorApplied;
      _goalEndDate = goalEndDate;
    });
  }

  void _onSliderChanged(double newPace) {
    final nowInCaution = TDEECalculator.isInCautionZone(newPace, ctrl.goal);
    if (nowInCaution != _wasInCautionZone) {
      HapticFeedback.mediumImpact();
      _wasInCautionZone = nowInCaution;
    }
    _pace = newPace;
    _recalculate(newPace);
  }

  void _onConfirm() {
    ctrl.setPacePercent(_pace);
    ctrl.calculateAll();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondary) =>
            ResultsScreen(controller: ctrl),
        transitionsBuilder: (ctx, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isLoss = ctrl.goal == 'lose';
    final isInCaution = TDEECalculator.isInCautionZone(_pace, ctrl.goal);
    final tdee = _targetCalories + (isLoss ? _dailyAdjustment : -_dailyAdjustment);
    final deficitSurplus = isLoss ? -_dailyAdjustment : _dailyAdjustment;

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
                  const SizedBox(height: 36),

                  // Title
                  Text(
                    'How fast do you want to reach your goal?',
                    style: AppTextStyles.headingLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Drag the slider to set your pace. We\'ll calculate everything in real time.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 32),

                  // Pace label above slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isLoss ? 'Weight loss pace' : 'Weight gain pace',
                        style: AppTextStyles.caption,
                      ),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: _pace.toStringAsFixed(2),
                            style: AppTextStyles.body.copyWith(
                              color: isInCaution
                                  ? const Color(0xFFFF5252)
                                  : AppColors.primaryAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          TextSpan(
                              text: '% / week',
                              style: AppTextStyles.bodySecondary),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Gradient slider
                  _GradientSlider(
                    value: _pace,
                    min: isLoss ? 0.5 : 0.1,
                    max: isLoss ? 1.5 : 1.0,
                    isLoss: isLoss,
                    onChanged: _onSliderChanged,
                  ),

                  // Caution banner
                  AnimatedOpacity(
                    opacity: isInCaution ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _CautionBanner(
                      message: isLoss
                          ? 'Losing more than 1% of body weight per week increases the risk of muscle loss and nutrient deficiencies. Proceed with caution.'
                          : 'Gaining more than 0.8% of body weight per week is likely to include excess fat gain alongside muscle. Proceed with caution.',
                    ),
                  ),

                  // Floor warning
                  AnimatedOpacity(
                    opacity: _floorApplied ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _FloorWarning(sex: ctrl.biologicalSex),
                  ),

                  const SizedBox(height: 24),

                  // 2×2 stat grid
                  _StatGrid(
                    weeklyChangeKg: _weeklyChange,
                    targetCalories: _targetCalories,
                    deficitSurplus: deficitSurplus,
                    goalEndDate: _goalEndDate,
                    targetWeightSet: ctrl.targetWeightKg != null,
                    weightDiffSmall: ctrl.targetWeightKg != null &&
                        (ctrl.weightKg - ctrl.targetWeightKg!).abs() < 1,
                    isLoss: isLoss,
                    tdee: tdee,
                  ),

                  const SizedBox(height: 36),
                  PrimaryButton(
                    label: 'Confirm My Pace →',
                    onTap: _onConfirm,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom gradient slider
// ---------------------------------------------------------------------------
class _GradientSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool isLoss;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.isLoss,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        thumbShape: const _GreenThumbShape(),
        trackShape: _GradientTrackShape(isLoss: isLoss),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        overlayColor: AppColors.primaryAccent.withValues(alpha: 0.15),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

class _GreenThumbShape extends SliderComponentShape {
  const _GreenThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Shadow
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // White fill
    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    // Green ring
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = AppColors.primaryAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

class _GradientTrackShape extends RoundedRectSliderTrackShape {
  final bool isLoss;
  const _GradientTrackShape({required this.isLoss});

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        colors: isLoss
            ? const [
                Color(0xFF00C853), // green (safe)
                Color(0xFFFFB300), // amber (approaching caution)
                Color(0xFFFF5252), // red (caution zone)
              ]
            : const [
                Color(0xFF00C853),
                Color(0xFFFFB300),
                Color(0xFFFF5252),
              ],
        stops: isLoss ? const [0.0, 0.6, 1.0] : const [0.0, 0.75, 1.0],
      ).createShader(trackRect);

    final rRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(4),
    );
    context.canvas.drawRRect(rRect, paint);
  }
}

// ---------------------------------------------------------------------------
// Caution banner
// ---------------------------------------------------------------------------
class _CautionBanner extends StatelessWidget {
  final String message;
  const _CautionBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB300), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFFFFB300))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floor warning
// ---------------------------------------------------------------------------
class _FloorWarning extends StatelessWidget {
  final String sex;
  const _FloorWarning({required this.sex});

  @override
  Widget build(BuildContext context) {
    final floor = sex == 'female' ? '1,200' : '1,500';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.destructive, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.destructive, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "We've capped your target at the safe minimum of $floor kcal/day.",
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2×2 stat grid + full-width summary
// ---------------------------------------------------------------------------
class _StatGrid extends StatelessWidget {
  final double weeklyChangeKg;
  final double targetCalories;
  final double deficitSurplus;
  final DateTime? goalEndDate;
  final bool targetWeightSet;
  final bool weightDiffSmall;
  final bool isLoss;
  final double tdee;

  const _StatGrid({
    required this.weeklyChangeKg,
    required this.targetCalories,
    required this.deficitSurplus,
    required this.goalEndDate,
    required this.targetWeightSet,
    required this.weightDiffSmall,
    required this.isLoss,
    required this.tdee,
  });

  @override
  Widget build(BuildContext context) {
    final sign = isLoss ? '−' : '+';
    final defSurpColor = isLoss
        ? AppColors.destructive
        : AppColors.primaryAccent;

    // Goal date label
    String dateLine;
    String? subLine;
    if (weightDiffSmall) {
      dateLine = "You're nearly at your goal!";
    } else if (!targetWeightSet) {
      dateLine = 'Set a target weight';
      subLine = 'to see your timeline';
    } else if (goalEndDate == null) {
      dateLine = '—';
    } else {
      dateLine = DateHelpers.formatDate(goalEndDate!);
      final (weeks, days) = DateHelpers.weeksAndDaysUntil(goalEndDate!);
      subLine = '$weeks weeks, $days days from today';
      // Extremely long timeline warning
      if (goalEndDate!.difference(DateTime.now()).inDays > 730) {
        subLine = '$weeks weeks — a long journey, we\'ll adjust as you go';
      }
    }

    return Column(
      children: [
        // 2×2 grid
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: 'Weekly Change',
                value: '$sign${weeklyChangeKg.toStringAsFixed(2)} kg/wk',
                valueColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                label: 'Daily Target',
                value: '${targetCalories.toStringAsFixed(0)} kcal',
                valueColor: AppColors.primaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                label: isLoss ? 'Daily Deficit' : 'Daily Surplus',
                value: '$sign${deficitSurplus.abs().toStringAsFixed(0)} kcal/day',
                valueColor: defSurpColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                label: 'Goal Date',
                value: dateLine,
                subValue: subLine,
                valueColor: Colors.white,
              ),
            ),
          ],
        ),
        // Full-width summary only when date is known
        if (goalEndDate != null && !weightDiffSmall) ...[
          const SizedBox(height: 12),
          _FullWidthSummaryCard(goalEndDate: goalEndDate!),
        ],
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color valueColor;

  const _MiniCard({
    required this.label,
    required this.value,
    this.subValue,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: const Color(0xFF9E9E9E))),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 4),
            Text(subValue!,
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFF9E9E9E))),
          ],
        ],
      ),
    );
  }
}

class _FullWidthSummaryCard extends StatelessWidget {
  final DateTime goalEndDate;
  const _FullWidthSummaryCard({required this.goalEndDate});

  @override
  Widget build(BuildContext context) {
    final (weeks, days) = DateHelpers.weeksAndDaysUntil(goalEndDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined,
              color: AppColors.primaryAccent, size: 20),
          const SizedBox(width: 12),
          Text(
            '$weeks weeks and $days days from today',
            style: AppTextStyles.body.copyWith(
              color: AppColors.primaryAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
