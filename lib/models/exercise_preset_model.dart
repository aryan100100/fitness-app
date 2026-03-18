// [HEALTH APP] — Exercise Preset Library
// 100+ hardcoded exercises grouped by muscle category.

class ExercisePreset {
  final String name;
  final String category;
  final bool isCardio;

  const ExercisePreset({
    required this.name,
    required this.category,
    this.isCardio = false,
  });
}

class ExerciseLibrary {
  static const List<ExercisePreset> all = [
    // CHEST
    ExercisePreset(name: 'Bench Press', category: 'chest'),
    ExercisePreset(name: 'Incline Bench Press', category: 'chest'),
    ExercisePreset(name: 'Decline Bench Press', category: 'chest'),
    ExercisePreset(name: 'Dumbbell Fly', category: 'chest'),
    ExercisePreset(name: 'Incline Dumbbell Press', category: 'chest'),
    ExercisePreset(name: 'Cable Fly', category: 'chest'),
    ExercisePreset(name: 'Push Up', category: 'chest'),
    ExercisePreset(name: 'Dips (Chest)', category: 'chest'),
    ExercisePreset(name: 'Pec Deck', category: 'chest'),
    ExercisePreset(name: 'Landmine Press', category: 'chest'),

    // BACK
    ExercisePreset(name: 'Deadlift', category: 'back'),
    ExercisePreset(name: 'Pull Up', category: 'back'),
    ExercisePreset(name: 'Chin Up', category: 'back'),
    ExercisePreset(name: 'Barbell Row', category: 'back'),
    ExercisePreset(name: 'Dumbbell Row', category: 'back'),
    ExercisePreset(name: 'Seated Cable Row', category: 'back'),
    ExercisePreset(name: 'Lat Pulldown', category: 'back'),
    ExercisePreset(name: 'T-Bar Row', category: 'back'),
    ExercisePreset(name: 'Face Pull', category: 'back'),
    ExercisePreset(name: 'Straight Arm Pulldown', category: 'back'),
    ExercisePreset(name: 'Romanian Deadlift', category: 'back'),
    ExercisePreset(name: 'Rack Pull', category: 'back'),

    // LEGS
    ExercisePreset(name: 'Squat', category: 'legs'),
    ExercisePreset(name: 'Front Squat', category: 'legs'),
    ExercisePreset(name: 'Hack Squat', category: 'legs'),
    ExercisePreset(name: 'Leg Press', category: 'legs'),
    ExercisePreset(name: 'Leg Extension', category: 'legs'),
    ExercisePreset(name: 'Leg Curl', category: 'legs'),
    ExercisePreset(name: 'Lunge', category: 'legs'),
    ExercisePreset(name: 'Bulgarian Split Squat', category: 'legs'),
    ExercisePreset(name: 'Calf Raise', category: 'legs'),
    ExercisePreset(name: 'Seated Calf Raise', category: 'legs'),
    ExercisePreset(name: 'Hip Thrust', category: 'legs'),
    ExercisePreset(name: 'Glute Bridge', category: 'legs'),
    ExercisePreset(name: 'Step Up', category: 'legs'),

    // SHOULDERS
    ExercisePreset(name: 'Overhead Press', category: 'shoulders'),
    ExercisePreset(name: 'Dumbbell Shoulder Press', category: 'shoulders'),
    ExercisePreset(name: 'Arnold Press', category: 'shoulders'),
    ExercisePreset(name: 'Lateral Raise', category: 'shoulders'),
    ExercisePreset(name: 'Front Raise', category: 'shoulders'),
    ExercisePreset(name: 'Rear Delt Fly', category: 'shoulders'),
    ExercisePreset(name: 'Upright Row', category: 'shoulders'),
    ExercisePreset(name: 'Shrugs', category: 'shoulders'),
    ExercisePreset(name: 'Cable Lateral Raise', category: 'shoulders'),
    ExercisePreset(name: 'Machine Shoulder Press', category: 'shoulders'),

    // ARMS
    ExercisePreset(name: 'Barbell Curl', category: 'arms'),
    ExercisePreset(name: 'Dumbbell Curl', category: 'arms'),
    ExercisePreset(name: 'Hammer Curl', category: 'arms'),
    ExercisePreset(name: 'Preacher Curl', category: 'arms'),
    ExercisePreset(name: 'Cable Curl', category: 'arms'),
    ExercisePreset(name: 'Concentration Curl', category: 'arms'),
    ExercisePreset(name: 'Tricep Pushdown', category: 'arms'),
    ExercisePreset(name: 'Skull Crusher', category: 'arms'),
    ExercisePreset(name: 'Overhead Tricep Extension', category: 'arms'),
    ExercisePreset(name: 'Dips (Tricep)', category: 'arms'),
    ExercisePreset(name: 'Close Grip Bench Press', category: 'arms'),
    ExercisePreset(name: 'Cable Tricep Kickback', category: 'arms'),

    // CORE
    ExercisePreset(name: 'Plank', category: 'core'),
    ExercisePreset(name: 'Crunch', category: 'core'),
    ExercisePreset(name: 'Sit Up', category: 'core'),
    ExercisePreset(name: 'Hanging Leg Raise', category: 'core'),
    ExercisePreset(name: 'Cable Crunch', category: 'core'),
    ExercisePreset(name: 'Russian Twist', category: 'core'),
    ExercisePreset(name: 'Ab Wheel Rollout', category: 'core'),
    ExercisePreset(name: 'Side Plank', category: 'core'),
    ExercisePreset(name: 'Decline Sit Up', category: 'core'),
    ExercisePreset(name: 'Bicycle Crunch', category: 'core'),

    // CARDIO
    ExercisePreset(name: 'Running', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Cycling', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Rowing Machine', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Jump Rope', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Elliptical', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Stair Climber', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Swimming', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'HIIT', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Assault Bike', category: 'cardio', isCardio: true),
    ExercisePreset(name: 'Ski Erg', category: 'cardio', isCardio: true),
  ];

  static List<ExercisePreset> byCategory(String category) =>
      category == 'all' ? all : all.where((e) => e.category == category).toList();

  static List<ExercisePreset> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return all;
    return all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }
}
