// [HEALTH APP] — Exercise Set Model
// Represents a single set within a workout (e.g. "Bench Press — 3x10 @ 60kg").
// Supports both strength (sets/reps/weight) and cardio (duration/distance).

class ExerciseSetModel {
  final String? id;
  final String workoutId;       // FK → workouts.id
  final String exerciseName;    // e.g. "Bench Press", "Running"
  final String category;        // 'chest' | 'back' | 'legs' | 'shoulders' | 'arms' | 'core' | 'cardio' | 'other'
  final int setNumber;          // 1-indexed
  final int? reps;              // null for cardio
  final double? weightKg;       // null for cardio/bodyweight
  final int? durationSeconds;   // for cardio / timed exercises
  final double? distanceKm;     // for cardio
  final String? createdAt;

  const ExerciseSetModel({
    this.id,
    required this.workoutId,
    required this.exerciseName,
    required this.category,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceKm,
    this.createdAt,
  });

  factory ExerciseSetModel.fromJson(Map<String, dynamic> json) {
    return ExerciseSetModel(
      id: json['id'] as String?,
      workoutId: json['workout_id'] as String? ?? '',
      exerciseName: json['exercise_name'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'workout_id': workoutId,
      'exercise_name': exerciseName,
      'category': category,
      'set_number': setNumber,
      if (reps != null) 'reps': reps,
      if (weightKg != null) 'weight_kg': weightKg,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (distanceKm != null) 'distance_km': distanceKm,
    };
  }

  /// Human-readable summary for display in workout cards
  String get summary {
    if (reps != null && weightKg != null) {
      return '${weightKg!.toStringAsFixed(1)} kg × $reps';
    } else if (reps != null) {
      return '$reps reps (bodyweight)';
    } else if (durationSeconds != null) {
      final min = durationSeconds! ~/ 60;
      final sec = durationSeconds! % 60;
      final distStr = distanceKm != null ? ' · ${distanceKm!.toStringAsFixed(1)} km' : '';
      return '${min}m ${sec}s$distStr';
    }
    return 'Logged';
  }
}
