// [ZCTM] — Goal Reframing Models
// Translates TDEE calculations into vivid body-composition outcome language.
// No mention of calories, kcal, deficit, surplus, or TDEE in any output.

/// Mathematical goal data sent to Gemini for reframing.
class GoalInput {
  final String goal;                // 'lose' | 'gain' | 'maintain'
  final double currentWeightKg;
  final double? targetWeightKg;
  final String? bodyFatRange;       // e.g. '21-25' — used for BF composition context
  final String biologicalSex;       // 'male' | 'female'
  final int weeksToGoal;
  final int weeksToMidpoint;        // halfway milestone
  final String weightUnit;          // 'kg' | 'lbs' — for display in output

  const GoalInput({
    required this.goal,
    required this.currentWeightKg,
    this.targetWeightKg,
    this.bodyFatRange,
    required this.biologicalSex,
    required this.weeksToGoal,
    required this.weeksToMidpoint,
    required this.weightUnit,
  });

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'current_weight_kg': currentWeightKg,
        if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
        if (bodyFatRange != null) 'body_fat_range': bodyFatRange,
        'biological_sex': biologicalSex,
        'weeks_to_goal': weeksToGoal,
        'weeks_to_midpoint': weeksToMidpoint,
        'weight_unit': weightUnit,
      };
}

/// Three-part goal reframe returned by Gemini.
class GoalReframeResult {
  /// 1 sentence — the outcome in plain English (no process language).
  final String goalStatement;

  /// 2 sentences — concrete visual/physical description of what achieving the
  /// goal looks like. No numerical composition % unless unavoidable for context.
  final String whatThisLooksLike;

  /// 1 sentence — the halfway milestone marker.
  final String milestoneMarker;

  const GoalReframeResult({
    required this.goalStatement,
    required this.whatThisLooksLike,
    required this.milestoneMarker,
  });

  factory GoalReframeResult.fromJson(Map<String, dynamic> j) =>
      GoalReframeResult(
        goalStatement: j['goal_statement'] as String? ?? '',
        whatThisLooksLike: j['what_this_looks_like'] as String? ?? '',
        milestoneMarker: j['milestone_marker'] as String? ?? '',
      );
}
