// [HEALTH APP] — Progressive Overload Service
// Computes overload suggestions based on previous workout performance.

import '../../models/exercise_set_model.dart';

class OverloadSuggestion {
  final String message;
  const OverloadSuggestion({required this.message});
}

class ProgressiveOverloadService {
  ProgressiveOverloadService._();
  static final ProgressiveOverloadService instance = ProgressiveOverloadService._();

  /// Given the last session's sets for an exercise, suggest the next progression.
  /// Simple linear model: if all sets completed, suggest +2.5kg.
  /// If reps were low (<6), suggest same weight, aim for more reps.
  OverloadSuggestion computeSuggestion({
    required String exerciseName,
    required List<ExerciseSetModel> lastSets,
  }) {
    if (lastSets.isEmpty) {
      return const OverloadSuggestion(message: 'No previous data');
    }

    final strengthSets = lastSets
        .where((s) => s.reps != null && s.weightKg != null)
        .toList();

    if (strengthSets.isEmpty) {
      return const OverloadSuggestion(message: 'Log strength sets to get suggestions');
    }

    final lastWeight = strengthSets.last.weightKg!;
    final avgReps = strengthSets.map((s) => s.reps!).reduce((a, b) => a + b) /
        strengthSets.length;

    // If average reps >= 8, suggest weight increase
    if (avgReps >= 8) {
      final newWeight = lastWeight + 2.5;
      return OverloadSuggestion(
        message: '${newWeight.toStringAsFixed(1)}kg × ${avgReps.round()} reps',
      );
    }

    // If average reps < 8, suggest same weight but aim for more reps
    return OverloadSuggestion(
      message: '${lastWeight.toStringAsFixed(1)}kg × ${(avgReps + 1).round()} reps',
    );
  }
}
