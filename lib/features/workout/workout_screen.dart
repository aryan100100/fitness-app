// [HEALTH APP] — Workout Screen (Tab 3)
// Main workout tab: weekly summary stats, recent workout list, FAB to log new workout.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/workout_service.dart';
import '../../models/exercise_set_model.dart';
import '../../models/user_model.dart';
import '../../models/workout_model.dart';
import 'log_workout_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final UserModel user;
  const WorkoutScreen({super.key, required this.user});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _service = WorkoutService.instance;

  bool _isLoading = true;
  List<WorkoutModel> _recentWorkouts = [];
  int _weeklyCount = 0;
  int _weeklyMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = widget.user.id ?? '';
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final results = await Future.wait([
      _service.getWorkouts(
        userId,
        fromDate: _dateStr(twoWeeksAgo),
        toDate: _dateStr(now),
      ),
      _service.getWeeklyWorkoutCount(userId),
      _service.getWeeklyDurationMinutes(userId),
    ]);

    if (mounted) {
      setState(() {
        _recentWorkouts = results[0] as List<WorkoutModel>;
        _weeklyCount = results[1] as int;
        _weeklyMinutes = results[2] as int;
        _isLoading = false;
      });
    }
  }

  void _navigateToLogWorkout() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => LogWorkoutScreen(user: widget.user),
        ))
        .then((_) => _loadData());
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Workouts', style: AppTextStyles.headingMedium),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton.extended(
          onPressed: _navigateToLogWorkout,
          backgroundColor: AppColors.primaryAccent,
          icon: const Icon(Icons.add_rounded, color: Colors.black),
          label: Text('Log Workout',
              style: AppTextStyles.buttonLabel.copyWith(color: Colors.black)),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryAccent,
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryAccent))
            : ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Weekly summary cards
                  _WeeklySummaryRow(
                    workoutCount: _weeklyCount,
                    totalMinutes: _weeklyMinutes,
                  ),
                  const SizedBox(height: 24),

                  // Recent workouts header
                  Text('Recent Workouts', style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 12),

                  if (_recentWorkouts.isEmpty)
                    _EmptyState(onTap: _navigateToLogWorkout)
                  else
                    ..._recentWorkouts.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WorkoutCard(
                            workout: w,
                            service: _service,
                            onDelete: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: AppColors.cardSurface,
                                  title: Text('Delete workout?',
                                      style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.bold)),
                                  content: Text(
                                      'This will remove "${w.name}" and all its exercises.',
                                      style: AppTextStyles.bodySecondary),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text('Cancel',
                                          style: AppTextStyles.caption),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('Delete',
                                          style: AppTextStyles.caption
                                              .copyWith(
                                                  color:
                                                      AppColors.destructive)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await _service.deleteWorkout(w.id!);
                                _loadData();
                              }
                            },
                          ),
                        )),

                  const SizedBox(height: 160), // FAB + Nav Bar clearance
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// WEEKLY SUMMARY ROW
// =============================================================================

class _WeeklySummaryRow extends StatelessWidget {
  final int workoutCount;
  final int totalMinutes;

  const _WeeklySummaryRow({
    required this.workoutCount,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.fitness_center_rounded,
            value: '$workoutCount',
            label: 'This Week',
            color: AppColors.primaryAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer_rounded,
            value: '${totalMinutes}m',
            label: 'Total Time',
            color: AppColors.carbBar,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            value: workoutCount >= 3 ? 'Active' : '—',
            label: workoutCount >= 3 ? 'Consistency' : 'Needs Work',
            color: AppColors.fatBar,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.headingMedium.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// =============================================================================
// WORKOUT CARD
// =============================================================================

class _WorkoutCard extends StatefulWidget {
  final WorkoutModel workout;
  final WorkoutService service;
  final VoidCallback onDelete;

  const _WorkoutCard({
    required this.workout,
    required this.service,
    required this.onDelete,
  });

  @override
  State<_WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<_WorkoutCard> {
  bool _expanded = false;
  List<ExerciseSetModel>? _sets;

  Future<void> _toggleExpand() async {
    if (!_expanded && _sets == null) {
      final sets =
          await widget.service.getExerciseSets(widget.workout.id!);
      setState(() {
        _sets = sets;
        _expanded = true;
      });
    } else {
      setState(() => _expanded = !_expanded);
    }
  }

  IconData get _typeIcon => switch (widget.workout.type) {
        'cardio' => Icons.directions_run_rounded,
        'flexibility' => Icons.self_improvement_rounded,
        'sports' => Icons.sports_soccer_rounded,
        _ => Icons.fitness_center_rounded,
      };

  Color get _typeColor => switch (widget.workout.type) {
        'cardio' => AppColors.carbBar,
        'flexibility' => const Color(0xFFB39DDB),
        'sports' => AppColors.fatBar,
        _ => AppColors.primaryAccent,
      };

  @override
  Widget build(BuildContext context) {
    final w = widget.workout;
    final dateFormatted = _formatDate(w.date);

    return GestureDetector(
      onTap: _toggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _expanded ? _typeColor.withValues(alpha: 0.4) : AppColors.subtleBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon, color: _typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('$dateFormatted · ${w.durationMinutes} min',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppColors.secondaryText,
                ),
              ],
            ),

            // Expanded exercise sets
            if (_expanded && _sets != null) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 12),
              if (_sets!.isEmpty)
                Text('No exercises logged.',
                    style: AppTextStyles.caption)
              else
                ..._groupedExercises(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppColors.destructive),
                  label: Text('Delete',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.destructive)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Groups exercise sets by exercise name for display.
  List<Widget> _groupedExercises() {
    final Map<String, List<ExerciseSetModel>> grouped = {};
    for (final s in _sets!) {
      grouped.putIfAbsent(s.exerciseName, () => []).add(s);
    }
    return grouped.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.key,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...entry.value.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(
                    'Set ${s.setNumber}: ${s.summary}',
                    style: AppTextStyles.caption,
                  ),
                )),
          ],
        ),
      );
    }).toList();
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(d).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return DateFormat('EEE, MMM d').format(d);
    } catch (_) {
      return dateStr;
    }
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded,
              size: 48, color: AppColors.secondaryText.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No workouts yet',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: 4),
          Text('Tap the button below to log your first workout!',
              style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Log Workout',
                style:
                    AppTextStyles.buttonLabel.copyWith(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
