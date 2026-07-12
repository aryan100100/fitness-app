// [ZCTM] — Auto-Adjustment Card Models
// Input/output for translating engine events into warm plain-language cards.

/// Adjustment types the engine can surface.
enum ZCTMAdjustmentType {
  rapidLoss,        // pace too fast — protect muscle
  plateau,          // weight not moving as expected
  loggingGap,       // user hasn't logged recently
  goalApproaching,  // goal date within 7 days
  weeklyRecalc,     // regular weekly target update
}

extension ZCTMAdjustmentTypeX on ZCTMAdjustmentType {
  String get value => switch (this) {
        ZCTMAdjustmentType.rapidLoss => 'rapid_loss',
        ZCTMAdjustmentType.plateau => 'plateau',
        ZCTMAdjustmentType.loggingGap => 'logging_gap',
        ZCTMAdjustmentType.goalApproaching => 'goal_approaching',
        ZCTMAdjustmentType.weeklyRecalc => 'weekly_recalc',
      };
}

/// Data sent to Gemini to translate an engine event into a card.
class AdjustmentInput {
  final String adjustmentType;           // ZCTMAdjustmentType.value
  final Map<String, dynamic> situationData; // flexible per type

  const AdjustmentInput({
    required this.adjustmentType,
    required this.situationData,
  });

  Map<String, dynamic> toJson() => {
        'adjustment_type': adjustmentType,
        'situation_data': situationData,
      };
}

/// Headline + body card copy returned by Gemini.
/// Headline: ≤8 words. Body: 1–2 sentences, ≤30 words total.
class AdjustmentCard {
  final String headline;
  final String body;

  const AdjustmentCard({required this.headline, required this.body});

  factory AdjustmentCard.fromJson(Map<String, dynamic> json) {
    return AdjustmentCard(
      headline: json['headline'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}
