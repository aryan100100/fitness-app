// [HEALTH APP] — Recalculate Plan Screen (Profile Feature)
// Lets user adjust weight, pace, and activity and recalculates all targets.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../models/user_model.dart';

class RecalculatePlanScreen extends StatefulWidget {
  final UserModel user;
  const RecalculatePlanScreen({super.key, required this.user});

  @override
  State<RecalculatePlanScreen> createState() => _RecalculatePlanScreenState();
}

class _RecalculatePlanScreenState extends State<RecalculatePlanScreen> {
  late TextEditingController _weightCtrl;
  late String _activityLevel;
  late double _pacePercent;
  bool _isSaving = false;
  NutritionPlan? _preview;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.user.weightKg.toStringAsFixed(1));
    _activityLevel = widget.user.activityLevel;
    _pacePercent = widget.user.weeklyPacePercent ?? 0.75;
    _recalculatePreview();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _recalculatePreview() {
    final w = double.tryParse(_weightCtrl.text) ?? widget.user.weightKg;
    final updatedUser = widget.user.copyWith(
      weightKg: w,
      activityLevel: _activityLevel,
    );
    setState(() {
      _preview = TDEECalculator.calculateAll(
        user: updatedUser,
        weeklyPacePercent: _pacePercent,
      );
    });
  }

  Future<void> _save() async {
    final w = double.tryParse(_weightCtrl.text) ?? widget.user.weightKg;
    final updatedUser = widget.user.copyWith(
      weightKg: w,
      activityLevel: _activityLevel,
    );
    final plan = TDEECalculator.calculateAll(
      user: updatedUser,
      weeklyPacePercent: _pacePercent,
    );

    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await Supabase.instance.client.from('users').update({
        'weight_kg': w,
        'activity_level': _activityLevel,
        'weekly_pace_percent': _pacePercent,
        'tdee': plan.tdee,
        'target_calories': plan.targetCalories,
        'protein_g': plan.proteinG,
        'carbs_g': plan.carbsG,
        'fat_g': plan.fatG,
        'fiber_g': plan.fiberG,
        'daily_deficit_surplus': plan.dailyDeficitSurplus,
      }).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Plan updated ✅ Your new targets are live.'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[RECALCULATE] save error: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Couldn't save — try again"),
          backgroundColor: AppColors.destructive,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final goalLabel = widget.user.goal == 'maintain'
        ? '(maintaining)'
        : widget.user.goal == 'lose'
            ? '(losing weight)'
            : '(gaining muscle)';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.primaryText,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Recalculate My Plan', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adjust your inputs $goalLabel',
                style: AppTextStyles.bodySecondary),
            const SizedBox(height: 20),

            // ── Current weight ────────────────────────────────────────────────
            Text('Current weight (kg)',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: AppTextStyles.body,
              onChanged: (_) => _recalculatePreview(),
              decoration: InputDecoration(
                hintText: 'e.g. 75.0',
                hintStyle: AppTextStyles.bodySecondary,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primaryAccent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Activity level ─────────────────────────────────────────────────
            Text('Activity level',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...(['sedentary','lightly_active','moderately_active','very_active'])
                .asMap()
                .entries
                .map((e) {
              final labels = const [
                'Sedentary (desk job, no exercise)',
                'Lightly active (1–3 workouts/week)',
                'Moderately active (3–5 workouts/week)',
                'Very active (6–7 workouts/week)',
              ];
              final selected = _activityLevel == e.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _activityLevel = e.value);
                  _recalculatePreview();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryAccent.withValues(alpha: 0.12)
                        : AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? AppColors.primaryAccent
                            : AppColors.divider),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(labels[e.key],
                          style: TextStyle(
                            fontSize: 14,
                            color: selected
                                ? AppColors.primaryAccent
                                : AppColors.primaryText,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryAccent, size: 18),
                  ]),
                ),
              );
            }),

            if (widget.user.goal != 'maintain') ...[
              const SizedBox(height: 20),
              Text('Pace — ${_pacePercent.toStringAsFixed(2)}% of bodyweight per week',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '≈ ${(double.tryParse(_weightCtrl.text) ?? widget.user.weightKg) * _pacePercent / 100 * 7 / 7 * 1000 ~/ 10 / 100} kg per week',
                style: AppTextStyles.caption.copyWith(color: AppColors.primaryAccent),
              ),
              Slider(
                value: _pacePercent,
                min: 0.25,
                max: 1.5,
                divisions: 50,
                activeColor: AppColors.primaryAccent,
                inactiveColor: AppColors.divider,
                onChanged: (v) {
                  setState(() => _pacePercent = v);
                  _recalculatePreview();
                },
              ),
            ],

            if (p != null) ...[
              const SizedBox(height: 20),
              // ── Live preview ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2E1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your new targets',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryAccent)),
                    const SizedBox(height: 10),
                    _statRow('Daily calories', '${p.targetCalories.round()} kcal'),
                    _statRow('Protein', '${p.proteinG.round()}g'),
                    _statRow('Carbs', '${p.carbsG.round()}g'),
                    _statRow('Fat', '${p.fatG.round()}g'),
                    _statRow('TDEE', '${p.tdee.round()} kcal'),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text('Update my plan', style: AppTextStyles.buttonLabel),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          Text(value,
              style: AppTextStyles.body.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ]),
      );
}
