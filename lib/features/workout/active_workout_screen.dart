// [HEALTH APP] — Active Workout Screen
// Hevy-style live workout logging. One exercise per card, set rows with checkmarks.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/workout_session_provider.dart';
import '../../models/workout_session_model.dart';
import 'exercise_picker_sheet.dart';
import 'rest_timer_sheet.dart';
import 'workout_summary_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _provider = WorkoutSessionProvider.instance;
  final _userId = Supabase.instance.client.auth.currentUser?.id ?? '';

  void _openExercisePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExercisePickerSheet(
        onSelected: (preset) => _provider.addExercise(preset, _userId),
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Discard Workout?',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        content: Text('This session will be lost.',
            style: AppTextStyles.caption),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Going',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Discard',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _provider.discardSession();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _finishWorkout() async {
    final s = _provider.session;
    if (s == null) return;
    if (s.completedSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complete at least one set first.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primaryText)),
          backgroundColor: AppColors.cardSurface,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          session: s,
          userId: _userId,
        ),
      ),
    );
  }

  void _showRestTimer(int exerciseIndex, int setIndex) {
    final session = _provider.session;
    if (session == null) return;
    final ex = session.exercises[exerciseIndex];
    final nextSet = setIndex + 1 < ex.sets.length
        ? 'Set ${setIndex + 2} of ${ex.name}'
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RestTimerSheet(nextSetLabel: nextSet),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final session = _provider.session;
        if (session == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              _buildAppBar(session),
            ],
            body: session.exercises.isEmpty
                ? _buildEmptyState()
                : _buildExerciseList(session),
          ),
          bottomNavigationBar: _buildBottomBar(session),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(WorkoutSessionModel session) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
        onPressed: _confirmDiscard,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _editWorkoutName(session.name),
            child: Text(
              session.name,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          Text(
            _provider.elapsedLabel,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.primaryAccent, fontSize: 12),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: ElevatedButton(
            onPressed: _finishWorkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            child: Text('Finish',
                style: AppTextStyles.caption.copyWith(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_rounded,
              size: 48, color: AppColors.divider),
          const SizedBox(height: 16),
          Text('No exercises yet',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: 8),
          Text('Tap below to add your first exercise.',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildExerciseList(WorkoutSessionModel session) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: session.exercises.length,
      itemBuilder: (context, i) {
        return _ExerciseCard(
          exercise: session.exercises[i],
          exerciseIndex: i,
          previousPerf: _provider.getPreviousPerf(session.exercises[i].name),
          overloadSuggestion:
              _provider.getOverloadSuggestion(session.exercises[i].name),
          onAddSet: () => _provider.addSet(i),
          onRemove: () => _provider.removeExercise(i),
          onToggleSet: (si) {
            final completed = _provider.toggleSetComplete(i, si);
            if (completed) _showRestTimer(i, si);
          },
          onCycleType: (si) => _provider.cycleSetType(i, si),
          onWeightChanged: (si, w) => _provider.updateSetWeight(i, si, w),
          onRepsChanged: (si, r) => _provider.updateSetReps(i, si, r),
          onDurationChanged: (si, d) => _provider.updateSetDuration(i, si, d),
          onDistanceChanged: (si, d) => _provider.updateSetDistance(i, si, d),
          onRemoveSet: (si) => _provider.removeSet(i, si),
        );
      },
    );
  }

  Widget _buildBottomBar(WorkoutSessionModel session) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          Row(
            children: [
              Text(
                '${session.completedSets} / ${session.totalSets} sets',
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: session.totalSets > 0
                        ? session.completedSets / session.totalSets
                        : 0,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primaryAccent,
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openExercisePicker,
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.primaryAccent, size: 20),
              label: Text('Add Exercise',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.primaryAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editWorkoutName(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Workout Name',
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.elevatedCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _provider.updateName(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: Text('Save',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryAccent)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EXERCISE CARD
// =============================================================================

class _ExerciseCard extends StatelessWidget {
  final LiveExercise exercise;
  final int exerciseIndex;
  final String? previousPerf;
  final String? overloadSuggestion;
  final VoidCallback onAddSet;
  final VoidCallback onRemove;
  final void Function(int) onToggleSet;
  final void Function(int) onCycleType;
  final void Function(int, double?) onWeightChanged;
  final void Function(int, int?) onRepsChanged;
  final void Function(int, int?) onDurationChanged;
  final void Function(int, double?) onDistanceChanged;
  final void Function(int) onRemoveSet;

  const _ExerciseCard({
    required this.exercise,
    required this.exerciseIndex,
    required this.previousPerf,
    required this.overloadSuggestion,
    required this.onAddSet,
    required this.onRemove,
    required this.onToggleSet,
    required this.onCycleType,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name,
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        _capitalize(exercise.category),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.secondaryText),
                  onPressed: () => _showExerciseOptions(context),
                ),
              ],
            ),
          ),

          // Previous perf / overload chip
          if (previousPerf != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 13, color: AppColors.secondaryText),
                  const SizedBox(width: 4),
                  Text('Last: $previousPerf',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.secondaryText)),
                  if (overloadSuggestion != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 11, color: AppColors.primaryAccent),
                          const SizedBox(width: 3),
                          Text('Try ${_extractWeight(overloadSuggestion!)}',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryAccent,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text('SET',
                      style: AppTextStyles.caption.copyWith(fontSize: 10,
                          color: AppColors.secondaryText)),
                ),
                Expanded(
                  child: Text('PREV',
                      style: AppTextStyles.caption.copyWith(fontSize: 10,
                          color: AppColors.secondaryText)),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    exercise.isCardio ? 'SECS' : 'KG',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(fontSize: 10,
                        color: AppColors.secondaryText),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(
                    exercise.isCardio ? 'KM' : 'REPS',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(fontSize: 10,
                        color: AppColors.secondaryText),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // Set rows
          ...exercise.sets.asMap().entries.map((entry) {
            final si = entry.key;
            final set = entry.value;
            return _SetRow(
              setIndex: si,
              set: set,
              isCardio: exercise.isCardio,
              previousLabel: set.previousLabel,
              onToggle: () => onToggleSet(si),
              onCycleType: () => onCycleType(si),
              onWeightChanged: (v) => onWeightChanged(si, v),
              onRepsChanged: (v) => onRepsChanged(si, v),
              onDurationChanged: (v) => onDurationChanged(si, v),
              onDistanceChanged: (v) => onDistanceChanged(si, v),
              onLongPress: () => onRemoveSet(si),
            );
          }),

          // Add set
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add_rounded,
                  size: 16, color: AppColors.primaryAccent),
              label: Text('Add Set', style: AppTextStyles.captionAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showExerciseOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.destructive),
              title: Text('Remove Exercise',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.destructive)),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _extractWeight(String suggestion) {
    final match = RegExp(r'(\d+\.?\d*)kg').firstMatch(suggestion);
    return match != null ? '${match.group(1)}kg' : '';
  }
}

// =============================================================================
// SET ROW
// =============================================================================

class _SetRow extends StatelessWidget {
  final int setIndex;
  final LiveSet set;
  final bool isCardio;
  final String? previousLabel;
  final VoidCallback onToggle;
  final VoidCallback onCycleType;
  final void Function(double?) onWeightChanged;
  final void Function(int?) onRepsChanged;
  final void Function(int?) onDurationChanged;
  final void Function(double?) onDistanceChanged;
  final VoidCallback onLongPress;

  const _SetRow({
    required this.setIndex,
    required this.set,
    required this.isCardio,
    required this.previousLabel,
    required this.onToggle,
    required this.onCycleType,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = set.status == SetStatus.completed;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isCompleted
            ? AppColors.primaryAccent.withValues(alpha: 0.07)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            // Set type badge (tap to cycle)
            GestureDetector(
              onTap: onCycleType,
              child: SizedBox(
                width: 48,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor(set.type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _typeLabel(set.type),
                      style: AppTextStyles.caption.copyWith(
                        color: _typeColor(set.type),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Previous
            Expanded(
              child: Text(
                previousLabel ?? '—',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryText, fontSize: 11),
              ),
            ),

            // Weight / Duration
            SizedBox(
              width: 70,
              child: _miniInput(
                hint: isCardio ? 'secs' : 'kg',
                value: isCardio
                    ? set.durationSeconds?.toString()
                    : set.weightKg?.toStringAsFixed(1),
                isDecimal: !isCardio,
                onChanged: isCardio
                    ? (v) => onDurationChanged(int.tryParse(v ?? ''))
                    : (v) => onWeightChanged(double.tryParse(v ?? '')),
                completed: isCompleted,
              ),
            ),

            const SizedBox(width: 8),

            // Reps / Distance
            SizedBox(
              width: 70,
              child: _miniInput(
                hint: isCardio ? 'km' : 'reps',
                value: isCardio
                    ? set.distanceKm?.toStringAsFixed(1)
                    : set.reps?.toString(),
                isDecimal: isCardio,
                onChanged: isCardio
                    ? (v) => onDistanceChanged(double.tryParse(v ?? ''))
                    : (v) => onRepsChanged(int.tryParse(v ?? '')),
                completed: isCompleted,
              ),
            ),

            const SizedBox(width: 8),

            // Checkmark
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.primaryAccent
                      : AppColors.elevatedCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCompleted
                        ? AppColors.primaryAccent
                        : AppColors.divider,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: isCompleted ? Colors.black : AppColors.divider,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInput({
    required String hint,
    required String? value,
    required bool isDecimal,
    required void Function(String?) onChanged,
    required bool completed,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType:
          TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: isDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.caption.copyWith(
        color: completed ? AppColors.primaryAccent : AppColors.primaryText,
        fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
      ),
      textAlign: TextAlign.center,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption
            .copyWith(color: AppColors.divider, fontSize: 11),
        filled: true,
        fillColor:
            completed ? AppColors.primaryAccent.withValues(alpha: 0.1) : AppColors.elevatedCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        isDense: true,
      ),
    );
  }

  String _typeLabel(SetType type) => switch (type) {
        SetType.warmup => 'W',
        SetType.normal => '${setIndex + 1}',
        SetType.dropSet => 'D',
        SetType.failure => 'F',
      };

  Color _typeColor(SetType type) => switch (type) {
        SetType.warmup => Colors.orange,
        SetType.normal => AppColors.secondaryText,
        SetType.dropSet => Colors.purple,
        SetType.failure => AppColors.destructive,
      };
}
