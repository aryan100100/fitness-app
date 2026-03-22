// [HEALTH APP] — Workout Session Provider
// Holds live in-memory session state. Persists nothing until user taps Finish.

import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/workout_session_model.dart';
import '../../models/exercise_preset_model.dart';
import '../../models/exercise_set_model.dart';
import '../../models/workout_model.dart';
import 'workout_service.dart';
import 'progressive_overload_service.dart';

class WorkoutSessionProvider extends ChangeNotifier {
  WorkoutSessionProvider._();
  static final instance = WorkoutSessionProvider._();

  WorkoutSessionModel? _session;
  bool get hasActiveSession => _session != null;
  WorkoutSessionModel? get session => _session;

  Timer? _ticker;

  // Previous perf cache: exerciseName → label string
  final Map<String, String> _previousPerf = {};

  // Overload suggestion cache
  final Map<String, String> _overloadSuggestion = {};

  // ---------------------------------------------------------------------------
  // SESSION LIFECYCLE
  // ---------------------------------------------------------------------------

  void startSession({String name = 'Workout', String type = 'strength'}) {
    _session = WorkoutSessionModel(name: name, type: type);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }

  /// Start a session pre-loaded with exercises from a routine.
  void addExercisesFromRoutine(
    List<ExercisePreset> presets,
    String userId, {
    String routineName = 'Workout',
  }) {
    startSession(name: routineName, type: 'strength');
    for (final preset in presets) {
      addExercise(preset, userId);
    }
  }

  Future<void> discardSession() async {
    _ticker?.cancel();
    _ticker = null;
    _session = null;
    _previousPerf.clear();
    _overloadSuggestion.clear();
    notifyListeners();
  }

  /// Save workout to Supabase and clear session.
  Future<bool> finishSession(String userId) async {
    final s = _session;
    if (s == null) return false;

    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      debugPrint('[WORKOUT] Saving workout for user: $userId, date: $dateStr');

      final workout = await WorkoutService.instance.createWorkout(WorkoutModel(
        userId: userId,
        date: dateStr,
        name: s.name,
        type: s.type,
        durationMinutes: s.elapsed.inMinutes,
      ));

      if (workout?.id == null) {
        debugPrint('[WORKOUT] createWorkout returned null — check table/RLS/migration');
        return false;
      }

      debugPrint('[WORKOUT] Workout created: ${workout!.id}');

      final sets = <ExerciseSetModel>[];
      for (final ex in s.exercises) {
        for (int i = 0; i < ex.sets.length; i++) {
          final ls = ex.sets[i];
          if (ls.status != SetStatus.completed) continue;
          sets.add(ExerciseSetModel(
            workoutId: workout.id!,
            exerciseName: ex.name,
            category: ex.category,
            setNumber: i + 1,
            reps: ls.reps,
            weightKg: ls.weightKg,
            durationSeconds: ls.durationSeconds,
            distanceKm: ls.distanceKm,
          ));
        }
      }

      if (sets.isNotEmpty) {
        debugPrint('[WORKOUT] Saving ${sets.length} exercise sets...');
        await WorkoutService.instance.addExerciseSets(sets);
      }

      _ticker?.cancel();
      _ticker = null;
      _session = null;
      _previousPerf.clear();
      _overloadSuggestion.clear();
      notifyListeners();
      debugPrint('[WORKOUT] Save complete!');
      return true;
    } catch (e, stack) {
      debugPrint('[WORKOUT] finishSession error: $e');
      debugPrint('[WORKOUT] stack: $stack');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // EXERCISE MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<void> addExercise(ExercisePreset preset, String userId) async {
    _session?.exercises.add(LiveExercise(
      name: preset.name,
      category: preset.category,
      isCardio: preset.isCardio,
    ));
    notifyListeners();

    // Fetch previous performance in background
    _fetchPreviousPerf(preset.name, userId);
  }

  void removeExercise(int index) {
    _session?.exercises.removeAt(index);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SET MANAGEMENT
  // ---------------------------------------------------------------------------

  void addSet(int exerciseIndex) {
    final exercise = _session?.exercises[exerciseIndex];
    if (exercise == null) return;

    // Pre-fill weight/reps from the last set
    final lastSet = exercise.sets.isNotEmpty ? exercise.sets.last : null;
    exercise.sets.add(LiveSet(
      weightKg: lastSet?.weightKg,
      reps: lastSet?.reps,
    ));
    notifyListeners();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    _session?.exercises[exerciseIndex].sets.removeAt(setIndex);
    notifyListeners();
  }

  void updateSetWeight(int exerciseIndex, int setIndex, double? weight) {
    final s = _session?.exercises[exerciseIndex].sets[setIndex];
    if (s == null) return;
    s.weightKg = weight;
    notifyListeners();
  }

  void updateSetReps(int exerciseIndex, int setIndex, int? reps) {
    final s = _session?.exercises[exerciseIndex].sets[setIndex];
    if (s == null) return;
    s.reps = reps;
    notifyListeners();
  }

  void updateSetDuration(int exerciseIndex, int setIndex, int? seconds) {
    final s = _session?.exercises[exerciseIndex].sets[setIndex];
    if (s == null) return;
    s.durationSeconds = seconds;
    notifyListeners();
  }

  void updateSetDistance(int exerciseIndex, int setIndex, double? km) {
    final s = _session?.exercises[exerciseIndex].sets[setIndex];
    if (s == null) return;
    s.distanceKm = km;
    notifyListeners();
  }

  /// Toggle a set complete/incomplete. Returns true if just completed (to trigger rest timer).
  bool toggleSetComplete(int exerciseIndex, int setIndex) {
    final s = _session?.exercises[exerciseIndex].sets[setIndex];
    if (s == null) return false;

    if (s.status == SetStatus.completed) {
      s.status = SetStatus.pending;
      notifyListeners();
      return false;
    } else {
      s.status = SetStatus.completed;
      notifyListeners();
      return true;
    }
  }

  void cycleSetType(int exerciseIndex, int setIndex) {
    final s = _session?.exercises[exerciseIndex].sets[setIndex];
    if (s == null) return;
    const types = SetType.values;
    final next = (types.indexOf(s.type) + 1) % types.length;
    s.type = types[next];
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PREVIOUS PERFORMANCE
  // ---------------------------------------------------------------------------

  String? getPreviousPerf(String exerciseName) => _previousPerf[exerciseName];
  String? getOverloadSuggestion(String exerciseName) =>
      _overloadSuggestion[exerciseName];

  Future<void> _fetchPreviousPerf(String exerciseName, String userId) async {
    final lastSets = await WorkoutService.instance.getLastSessionForExercise(
      userId: userId,
      exerciseName: exerciseName,
    );

    if (lastSets.isEmpty) return;

    final strengthSets =
        lastSets.where((s) => s.reps != null && s.weightKg != null).toList();
    if (strengthSets.isNotEmpty) {
      final weight = strengthSets.last.weightKg!;
      final reps = strengthSets.last.reps!;
      final totalSets = strengthSets.length;
      _previousPerf[exerciseName] =
          '$totalSets×$reps @ ${weight.toStringAsFixed(1)}kg';

      // Overload suggestion
      final suggestion = ProgressiveOverloadService.instance.computeSuggestion(
        exerciseName: exerciseName,
        lastSets: lastSets,
      );
      _overloadSuggestion[exerciseName] = suggestion.message;
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SESSION NAME / TYPE
  // ---------------------------------------------------------------------------

  void updateName(String name) {
    if (_session == null) return;
    _session!.name = name;
    notifyListeners();
  }

  void updateType(String type) {
    if (_session == null) return;
    _session!.type = type;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ELAPSED TIMER STRING
  // ---------------------------------------------------------------------------

  String get elapsedLabel {
    final d = _session?.elapsed ?? Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
