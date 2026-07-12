// [HEALTH APP] — Workout Service
// Supabase CRUD for workouts and exercise sets.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/workout_model.dart';
import '../../models/exercise_set_model.dart';

class WorkoutService {
  WorkoutService._();
  static final WorkoutService instance = WorkoutService._();

  final _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // WORKOUTS CRUD
  // ---------------------------------------------------------------------------

  /// Create a new workout and return the created record (with server-generated id).
  Future<WorkoutModel?> createWorkout(WorkoutModel workout) async {
    try {
      final res = await _client
          .from('workouts')
          .insert(workout.toJson())
          .select()
          .single();
      return WorkoutModel.fromJson(res);
    } catch (e) {
      debugPrint('[WORKOUT_SERVICE] createWorkout error: $e');
      return null;
    }
  }

  /// Fetch workouts for a user within a date range (inclusive), newest first.
  Future<List<WorkoutModel>> getWorkouts(
    String userId, {
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final res = await _client
          .from('workouts')
          .select()
          .eq('user_id', userId)
          .gte('date', fromDate)
          .lte('date', toDate)
          .order('date', ascending: false)
          .order('created_at', ascending: false);
      return (res as List).map((e) => WorkoutModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch all workouts for a specific date.
  Future<List<WorkoutModel>> getWorkoutsForDate(String userId, String date) async {
    try {
      final res = await _client
          .from('workouts')
          .select()
          .eq('user_id', userId)
          .eq('date', date)
          .order('created_at', ascending: false);
      return (res as List).map((e) => WorkoutModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a workout (cascade deletes its exercise sets).
  Future<bool> deleteWorkout(String workoutId) async {
    try {
      await _client.from('workouts').delete().eq('id', workoutId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // EXERCISE SETS CRUD
  // ---------------------------------------------------------------------------

  /// Add exercise sets to a workout.
  Future<bool> addExerciseSets(List<ExerciseSetModel> sets) async {
    if (sets.isEmpty) return true;
    try {
      await _client
          .from('exercise_sets')
          .insert(sets.map((s) => s.toJson()).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch all exercise sets for a workout.
  Future<List<ExerciseSetModel>> getExerciseSets(String workoutId) async {
    try {
      final res = await _client
          .from('exercise_sets')
          .select()
          .eq('workout_id', workoutId)
          .order('exercise_name')
          .order('set_number');
      return (res as List).map((e) => ExerciseSetModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a single exercise set.
  Future<bool> deleteExerciseSet(String setId) async {
    try {
      await _client.from('exercise_sets').delete().eq('id', setId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // STATS / HELPERS
  // ---------------------------------------------------------------------------

  /// Get the total number of workouts this week (Mon-Sun).
  Future<int> getWeeklyWorkoutCount(String userId) async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final from = _dateStr(monday);
      final to = _dateStr(sunday);

      final res = await _client
          .from('workouts')
          .select('id')
          .eq('user_id', userId)
          .gte('date', from)
          .lte('date', to);
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Get the total duration logged this week in minutes.
  Future<int> getWeeklyDurationMinutes(String userId) async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final from = _dateStr(monday);
      final to = _dateStr(sunday);

      final res = await _client
          .from('workouts')
          .select('duration_minutes')
          .eq('user_id', userId)
          .gte('date', from)
          .lte('date', to);
      int total = 0;
      for (final row in (res as List)) {
        total += (row['duration_minutes'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Fetch the most recent session's sets for a given exercise name.
  /// Used for "previous performance" display and overload suggestions.
  Future<List<ExerciseSetModel>> getLastSessionForExercise({
    required String userId,
    required String exerciseName,
  }) async {
    try {
      // Find the most recent workout containing this exercise
      final workoutResult = await _client
          .from('exercise_sets')
          .select('workout_id, workouts!inner(user_id, date)')
          .eq('exercise_name', exerciseName)
          .eq('workouts.user_id', userId)
          .order('workouts(date)', ascending: false)
          .limit(1)
          .maybeSingle();

      if (workoutResult == null) return [];

      final workoutId = workoutResult['workout_id'] as String;

      final setsResult = await _client
          .from('exercise_sets')
          .select()
          .eq('workout_id', workoutId)
          .eq('exercise_name', exerciseName)
          .order('set_number');

      return (setsResult as List)
          .map((row) => ExerciseSetModel.fromJson(row))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // PERSONAL BEST DETECTION
  // ---------------------------------------------------------------------------

  /// Returns true if [weightKg] at [reps] beats every previously saved set
  /// for [exerciseName] at the same rep count in the last 90 days.
  Future<bool> checkIsPB({
    required String userId,
    required String exerciseName,
    required int reps,
    required double weightKg,
  }) async {
    try {
      final cutoff = _dateStr(DateTime.now().subtract(const Duration(days: 90)));
      final res = await _client
          .from('exercise_sets')
          .select('weight_kg, workouts!inner(user_id, date)')
          .eq('exercise_name', exerciseName)
          .eq('reps', reps)
          .eq('workouts.user_id', userId)
          .gte('workouts.date', cutoff)
          .not('weight_kg', 'is', null);

      final rows = res as List;
      if (rows.isEmpty) return false;
      final maxPrev = rows.fold<double>(0, (max, row) {
        final w = (row['weight_kg'] as num?)?.toDouble() ?? 0;
        return w > max ? w : max;
      });
      return weightKg > maxPrev;
    } catch (_) {
      return false;
    }
  }

  /// Returns the heaviest single set for [exerciseName] in the last 90 days,
  /// or null if no historical data exists.
  Future<ExerciseSetModel?> getPersonalBest({
    required String userId,
    required String exerciseName,
  }) async {
    try {
      final cutoff = _dateStr(DateTime.now().subtract(const Duration(days: 90)));
      final res = await _client
          .from('exercise_sets')
          .select('*, workouts!inner(user_id, date)')
          .eq('exercise_name', exerciseName)
          .eq('workouts.user_id', userId)
          .gte('workouts.date', cutoff)
          .not('weight_kg', 'is', null)
          .order('weight_kg', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return ExerciseSetModel.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
