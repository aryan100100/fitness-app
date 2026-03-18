// [HEALTH APP] — In-Memory Workout Session Model
// Holds the live state of an active workout before it's saved to Supabase.

enum SetType { warmup, normal, dropSet, failure }

enum SetStatus { pending, completed }

class LiveSet {
  SetType type;
  SetStatus status;
  double? weightKg;
  int? reps;
  int? durationSeconds;
  double? distanceKm;
  String? previousLabel; // e.g. "60kg × 8"

  LiveSet({
    this.type = SetType.normal,
    this.status = SetStatus.pending,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.distanceKm,
    this.previousLabel,
  });

  LiveSet copyWith({
    SetType? type,
    SetStatus? status,
    double? weightKg,
    int? reps,
    int? durationSeconds,
    double? distanceKm,
    String? previousLabel,
  }) {
    return LiveSet(
      type: type ?? this.type,
      status: status ?? this.status,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      previousLabel: previousLabel ?? this.previousLabel,
    );
  }
}

class LiveExercise {
  final String name;
  final String category;
  final bool isCardio;
  final List<LiveSet> sets;

  LiveExercise({
    required this.name,
    required this.category,
    this.isCardio = false,
    List<LiveSet>? sets,
  }) : sets = sets ?? [LiveSet()];
}

class WorkoutSessionModel {
  String name;
  String type; // strength | cardio | flexibility | sports
  final DateTime startTime;
  final List<LiveExercise> exercises;

  WorkoutSessionModel({
    this.name = 'Workout',
    this.type = 'strength',
    DateTime? startTime,
    List<LiveExercise>? exercises,
  })  : startTime = startTime ?? DateTime.now(),
        exercises = exercises ?? [];

  Duration get elapsed => DateTime.now().difference(startTime);

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);

  int get completedSets => exercises.fold(
      0, (sum, e) => sum + e.sets.where((s) => s.status == SetStatus.completed).length);

  double get totalVolumeKg {
    double vol = 0;
    for (final ex in exercises) {
      for (final s in ex.sets) {
        if (s.status == SetStatus.completed &&
            s.weightKg != null &&
            s.reps != null) {
          vol += s.weightKg! * s.reps!;
        }
      }
    }
    return vol;
  }
}
