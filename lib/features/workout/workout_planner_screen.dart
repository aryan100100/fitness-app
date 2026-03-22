// [HEALTH APP] — Workout Planner Screen
// Shows pre-built routine templates (PPL, Upper/Lower, Full Body).
// User picks a routine → session starts pre-loaded with those exercises.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/workout_session_provider.dart';
import '../../models/exercise_preset_model.dart';
import 'active_workout_screen.dart';

// ---------------------------------------------------------------------------
// ROUTINE DATA
// ---------------------------------------------------------------------------

class _Routine {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> exerciseNames;

  const _Routine({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.exerciseNames,
  });

  List<ExercisePreset> get presets => exerciseNames
      .map((n) => ExerciseLibrary.all.firstWhere(
            (e) => e.name == n,
            orElse: () => ExercisePreset(name: n, category: 'other'),
          ))
      .toList();
}

const _routines = <_Routine>[
  _Routine(
    name: 'Push Day',
    subtitle: 'Chest · Shoulders · Triceps',
    icon: Icons.fitness_center_rounded,
    accent: Color(0xFF64FFDA),
    exerciseNames: [
      'Bench Press',
      'Incline Dumbbell Press',
      'Cable Fly',
      'Overhead Press',
      'Lateral Raise',
      'Tricep Pushdown',
    ],
  ),
  _Routine(
    name: 'Pull Day',
    subtitle: 'Back · Biceps · Rear Delts',
    icon: Icons.accessibility_new_rounded,
    accent: Color(0xFF82B1FF),
    exerciseNames: [
      'Deadlift',
      'Barbell Row',
      'Lat Pulldown',
      'Face Pull',
      'Barbell Curl',
      'Hammer Curl',
    ],
  ),
  _Routine(
    name: 'Legs Day',
    subtitle: 'Quads · Hamstrings · Glutes · Calves',
    icon: Icons.directions_walk_rounded,
    accent: Color(0xFFFF8A65),
    exerciseNames: [
      'Squat',
      'Leg Press',
      'Leg Extension',
      'Leg Curl',
      'Calf Raise',
      'Hip Thrust',
    ],
  ),
  _Routine(
    name: 'Upper Body',
    subtitle: 'Chest · Back · Shoulders · Arms',
    icon: Icons.sports_gymnastics_rounded,
    accent: Color(0xFFCE93D8),
    exerciseNames: [
      'Bench Press',
      'Barbell Row',
      'Overhead Press',
      'Lat Pulldown',
      'Barbell Curl',
      'Tricep Pushdown',
    ],
  ),
  _Routine(
    name: 'Lower Body',
    subtitle: 'Quads · Hamstrings · Glutes · Calves',
    icon: Icons.directions_run_rounded,
    accent: Color(0xFFFFF176),
    exerciseNames: [
      'Squat',
      'Romanian Deadlift',
      'Leg Press',
      'Leg Extension',
      'Leg Curl',
      'Calf Raise',
    ],
  ),
  _Routine(
    name: 'Full Body',
    subtitle: 'Compound movements · All major groups',
    icon: Icons.bolt_rounded,
    accent: Color(0xFFA5D6A7),
    exerciseNames: [
      'Squat',
      'Bench Press',
      'Barbell Row',
      'Overhead Press',
      'Barbell Curl',
      'Plank',
    ],
  ),
];

// ---------------------------------------------------------------------------
// SCREEN
// ---------------------------------------------------------------------------

class WorkoutPlannerScreen extends StatelessWidget {
  const WorkoutPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
        title: Text('Routines',
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: _routines.length,
        itemBuilder: (context, i) => _RoutineCard(
          routine: _routines[i],
          onStart: () => _startRoutine(context, _routines[i]),
        ),
      ),
    );
  }

  void _startRoutine(BuildContext context, _Routine routine) {
    final provider = WorkoutSessionProvider.instance;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    provider.addExercisesFromRoutine(
      routine.presets,
      userId,
      routineName: routine.name,
    );

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) => const ActiveWorkoutScreen(),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ROUTINE CARD
// ---------------------------------------------------------------------------

class _RoutineCard extends StatelessWidget {
  final _Routine routine;
  final VoidCallback onStart;

  const _RoutineCard({required this.routine, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onStart,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: routine.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(routine.icon, color: routine.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routine.name,
                              style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(routine.subtitle,
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.play_circle_fill_rounded,
                        color: routine.accent, size: 32),
                  ],
                ),
                const SizedBox(height: 14),

                // Exercise list
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: routine.exerciseNames
                      .map((name) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.elevatedCard,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(name,
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
