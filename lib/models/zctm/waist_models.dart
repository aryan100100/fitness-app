// [ZCTM] — Waist Measurement Models
// Waist circumference is a body composition proxy used in ZCTM
// as an alternative progress signal to scale weight.

/// A single waist measurement entry.
class WaistEntry {
  final String date;   // yyyy-MM-dd
  final double waistCm;

  const WaistEntry({required this.date, required this.waistCm});

  Map<String, dynamic> toJson() => {'date': date, 'waist_cm': waistCm};
}

/// Input for waist trend contextualisation Gemini call.
class WaistContextInput {
  final List<WaistEntry> measurements; // chronological, last N weeks
  final double startWaistCm;
  final double currentWaistCm;
  final bool isMenstrualWeek;
  final String goal; // 'lose' | 'gain' | 'maintain'

  const WaistContextInput({
    required this.measurements,
    required this.startWaistCm,
    required this.currentWaistCm,
    required this.isMenstrualWeek,
    required this.goal,
  });

  Map<String, dynamic> toJson() => {
        'measurements': measurements.map((e) => e.toJson()).toList(),
        'start_waist_cm': startWaistCm,
        'current_waist_cm': currentWaistCm,
        'is_menstrual_week': isMenstrualWeek,
        'goal': goal,
      };
}

/// Trend direction for waist context.
enum WaistTrend { improving, stable, increasing }

extension WaistTrendX on WaistTrend {
  static WaistTrend fromString(String s) => switch (s) {
        'improving' => WaistTrend.improving,
        'stable' => WaistTrend.stable,
        _ => WaistTrend.increasing,
      };
}

/// Contextual message returned by Gemini for waist trend.
class WaistContextMessage {
  final String message; // 2 sentences max, warm, non-judgmental
  final WaistTrend trend;

  const WaistContextMessage({required this.message, required this.trend});

  factory WaistContextMessage.fromJson(Map<String, dynamic> j) =>
      WaistContextMessage(
        message: j['message'] as String? ?? '',
        trend: WaistTrendX.fromString(j['trend'] as String? ?? 'stable'),
      );
}
