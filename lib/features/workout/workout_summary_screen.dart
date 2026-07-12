// [HEALTH APP] — Workout Summary Screen
// Post-finish screen with volume, duration, PR badges, per-exercise breakdown.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/workout_service.dart';
import '../../core/services/workout_session_provider.dart';
import '../../core/utils/weight_utils.dart';
import '../../models/workout_session_model.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final WorkoutSessionModel session;
  final String userId;
  final String weightUnit; // 'kg' or 'lbs' — defaults to 'kg' if not threaded

  const WorkoutSummaryScreen({
    super.key,
    required this.session,
    required this.userId,
    this.weightUnit = 'kg',
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool _saving = false;
  // Real PB results: exerciseName → true if best set in this session is a PB
  final Map<String, bool> _pbResults = {};

  @override
  void initState() {
    super.initState();
    _checkPBs();
  }

  Future<void> _checkPBs() async {
    for (final ex in widget.session.exercises) {
      final completed = ex.sets
          .where((s) =>
              s.status == SetStatus.completed &&
              s.weightKg != null &&
              s.reps != null)
          .toList();
      if (completed.isEmpty) continue;
      final best = completed.reduce(
          (a, b) => (a.weightKg ?? 0) > (b.weightKg ?? 0) ? a : b);
      final isPb = await WorkoutService.instance.checkIsPB(
        userId: widget.userId,
        exerciseName: ex.name,
        reps: best.reps!,
        weightKg: best.weightKg!,
      );
      if (mounted) setState(() => _pbResults[ex.name] = isPb);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final success = await WorkoutSessionProvider.instance
        .finishSession(widget.userId);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save. Try again.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primaryText)),
          backgroundColor: AppColors.cardSurface,
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final completedExercises = session.exercises
        .where((e) => e.sets.any((s) => s.status == SetStatus.completed))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
        title: Text('Workout Complete', style: AppTextStyles.body
            .copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trophy header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 32, color: AppColors.primaryAccent),
                  ),
                  const SizedBox(height: 12),
                  Text(session.name,
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    'Great work! Here\'s your summary.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Stats row
            Row(
              children: [
                _StatCard(
                  label: 'Duration',
                  value: _formatDuration(session.elapsed),
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Volume',
                  value: formatWeight(session.totalVolumeKg, widget.weightUnit),
                  icon: Icons.bar_chart_rounded,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Sets',
                  value: '${session.completedSets}',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
            ),

            const SizedBox(height: 28),
            Text('Exercises',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),

            // Per-exercise breakdown
            ...completedExercises.map((ex) {
              final completedSets =
                  ex.sets.where((s) => s.status == SetStatus.completed).toList();
              final bestWeight = completedSets
                  .where((s) => s.weightKg != null)
                  .fold<double>(0, (max, s) => s.weightKg! > max ? s.weightKg! : max);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.name,
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${completedSets.length} sets'
                            '${bestWeight > 0 ? ' · Best: ${formatWeight(bestWeight, widget.weightUnit)}' : ''}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    // Real PB badge (Fix B)
                    if (_pbResults[ex.name] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text('New PB!',
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text('Save Workout',
                        style: AppTextStyles.buttonLabel
                            .copyWith(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryAccent),
            const SizedBox(height: 6),
            Text(value,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
