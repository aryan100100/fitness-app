// [HEALTH APP] — Log Workout Screen
// Multi-step form: workout metadata (name, type, duration) → exercise entry → save.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/workout_service.dart';
import '../../models/exercise_set_model.dart';
import '../../models/user_model.dart';
import '../../models/workout_model.dart';

class LogWorkoutScreen extends StatefulWidget {
  final UserModel user;
  const LogWorkoutScreen({super.key, required this.user});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _service = WorkoutService.instance;

  // --- Workout metadata ---
  final _nameCtrl = TextEditingController(text: 'Workout');
  String _type = 'strength';
  final _durationCtrl = TextEditingController(text: '45');
  final _notesCtrl = TextEditingController();

  // --- Exercise builder ---
  final List<_ExerciseEntry> _exercises = [];
  bool _isSaving = false;

  static const _workoutTypes = [
    ('strength', 'Strength', Icons.fitness_center_rounded),
    ('cardio', 'Cardio', Icons.directions_run_rounded),
    ('flexibility', 'Flexibility', Icons.self_improvement_rounded),
    ('sports', 'Sports', Icons.sports_soccer_rounded),
  ];

  static const _categories = [
    'chest',
    'back',
    'legs',
    'shoulders',
    'arms',
    'core',
    'cardio',
    'other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  void _addExercise() {
    setState(() {
      _exercises.add(_ExerciseEntry(
        isCardio: _type == 'cardio',
      ));
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises[index].dispose();
      _exercises.removeAt(index);
    });
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      _exercises[exerciseIndex].sets.add(_SetEntry());
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      _exercises[exerciseIndex].sets[setIndex].dispose();
      _exercises[exerciseIndex].sets.removeAt(setIndex);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a workout name.');
      return;
    }
    final duration = int.tryParse(_durationCtrl.text) ?? 0;
    if (duration <= 0) {
      _showError('Please enter workout duration.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Create workout
      final workout = await _service.createWorkout(WorkoutModel(
        userId: userId,
        date: dateStr,
        name: name,
        type: _type,
        durationMinutes: duration,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));

      if (workout == null || workout.id == null) {
        throw Exception('Failed to create workout');
      }

      // Create exercise sets
      final sets = <ExerciseSetModel>[];
      for (final exercise in _exercises) {
        final exerciseName = exercise.nameCtrl.text.trim();
        if (exerciseName.isEmpty) continue;

        for (int i = 0; i < exercise.sets.length; i++) {
          final s = exercise.sets[i];
          sets.add(ExerciseSetModel(
            workoutId: workout.id!,
            exerciseName: exerciseName,
            category: exercise.category,
            setNumber: i + 1,
            reps: int.tryParse(s.repsCtrl.text),
            weightKg: double.tryParse(s.weightCtrl.text),
            durationSeconds: int.tryParse(s.durationCtrl.text),
            distanceKm: double.tryParse(s.distanceCtrl.text),
          ));
        }
      }

      if (sets.isNotEmpty) {
        await _service.addExerciseSets(sets);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Could not save workout. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: AppTextStyles.caption.copyWith(color: AppColors.primaryText)),
        backgroundColor: AppColors.cardSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
        title: Text('Log Workout', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- WORKOUT INFO SECTION ---
            Text('Workout Details',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            _buildTextField('Workout Name', _nameCtrl, TextInputType.text),
            const SizedBox(height: 12),

            // Type selector chips
            Text('Type', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _workoutTypes.map((t) {
                final selected = _type == t.$1;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t.$1),
                  avatar: Icon(t.$3,
                      size: 16,
                      color: selected ? Colors.black : AppColors.secondaryText),
                  label: Text(t.$2,
                      style: AppTextStyles.caption.copyWith(
                        color: selected ? Colors.black : AppColors.primaryText,
                      )),
                  selectedColor: AppColors.primaryAccent,
                  backgroundColor: AppColors.cardSurface,
                  side: BorderSide(
                      color: selected
                          ? AppColors.primaryAccent
                          : AppColors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            _buildTextField(
                'Duration (minutes)', _durationCtrl, TextInputType.number),
            const SizedBox(height: 12),
            _buildTextField(
                'Notes (optional)', _notesCtrl, TextInputType.multiline,
                maxLines: 2),

            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),

            // --- EXERCISES SECTION ---
            Row(
              children: [
                Expanded(
                  child: Text('Exercises',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add_rounded,
                      size: 18, color: AppColors.primaryAccent),
                  label: Text('Add Exercise',
                      style: AppTextStyles.captionAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_exercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Center(
                  child: Text(
                    'Tap "Add Exercise" to start building your workout.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...List.generate(_exercises.length, (i) {
                return _ExerciseCard(
                  key: ValueKey(i),
                  entry: _exercises[i],
                  index: i,
                  categories: _categories,
                  isCardio: _type == 'cardio',
                  onRemove: () => _removeExercise(i),
                  onAddSet: () => _addSet(i),
                  onRemoveSet: (si) => _removeSet(i, si),
                );
              }),

            const SizedBox(height: 32),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
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

  Widget _buildTextField(
      String label, TextEditingController ctrl, TextInputType type,
      {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: AppTextStyles.body,
      inputFormatters: type == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// =============================================================================
// EXERCISE ENTRY DATA CLASS
// =============================================================================

class _ExerciseEntry {
  final TextEditingController nameCtrl = TextEditingController();
  String category;
  final List<_SetEntry> sets = [];

  _ExerciseEntry({bool isCardio = false})
      : category = isCardio ? 'cardio' : 'chest' {
    sets.add(_SetEntry()); // Start with 1 set
  }

  void dispose() {
    nameCtrl.dispose();
    for (final s in sets) {
      s.dispose();
    }
  }
}

class _SetEntry {
  final TextEditingController repsCtrl = TextEditingController();
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController durationCtrl = TextEditingController();
  final TextEditingController distanceCtrl = TextEditingController();

  void dispose() {
    repsCtrl.dispose();
    weightCtrl.dispose();
    durationCtrl.dispose();
    distanceCtrl.dispose();
  }
}

// =============================================================================
// EXERCISE CARD WIDGET
// =============================================================================

class _ExerciseCard extends StatelessWidget {
  final _ExerciseEntry entry;
  final int index;
  final List<String> categories;
  final bool isCardio;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final void Function(int) onRemoveSet;

  const _ExerciseCard({
    super.key,
    required this.entry,
    required this.index,
    required this.categories,
    required this.isCardio,
    required this.onRemove,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header
          Row(
            children: [
              Expanded(
                child: Text('Exercise ${index + 1}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primaryAccent)),
              ),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.destructive),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Exercise name
          TextFormField(
            controller: entry.nameCtrl,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: isCardio ? 'e.g. Running, Cycling' : 'e.g. Bench Press',
              hintStyle: AppTextStyles.caption,
              filled: true,
              fillColor: AppColors.elevatedCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),

          // Category picker
          if (!isCardio) ...[
            DropdownButtonFormField<String>(
              initialValue: entry.category,
              dropdownColor: AppColors.elevatedCard,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Muscle Group',
                labelStyle: AppTextStyles.caption,
                filled: true,
                fillColor: AppColors.elevatedCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_capitalize(c),
                            style: AppTextStyles.body),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) entry.category = v;
              },
            ),
            const SizedBox(height: 12),
          ],

          // Sets
          ...List.generate(entry.sets.length, (si) {
            final s = entry.sets[si];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Set label
                  SizedBox(
                    width: 36,
                    child: Text('S${si + 1}',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (!isCardio) ...[
                    // Reps
                    Expanded(
                      child: _miniField(s.repsCtrl, 'Reps'),
                    ),
                    const SizedBox(width: 8),
                    // Weight
                    Expanded(
                      child: _miniField(s.weightCtrl, 'kg'),
                    ),
                  ] else ...[
                    // Duration seconds
                    Expanded(
                      child: _miniField(s.durationCtrl, 'Seconds'),
                    ),
                    const SizedBox(width: 8),
                    // Distance
                    Expanded(
                      child: _miniField(s.distanceCtrl, 'km'),
                    ),
                  ],
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: entry.sets.length > 1
                        ? () => onRemoveSet(si)
                        : null,
                    child: Icon(Icons.remove_circle_outline_rounded,
                        size: 18,
                        color: entry.sets.length > 1
                            ? AppColors.destructive
                            : AppColors.divider),
                  ),
                ],
              ),
            );
          }),

          // Add set button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add_rounded,
                  size: 16, color: AppColors.primaryAccent),
              label:
                  Text('Add Set', style: AppTextStyles.captionAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.caption.copyWith(color: AppColors.primaryText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption.copyWith(fontSize: 11),
        filled: true,
        fillColor: AppColors.elevatedCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
