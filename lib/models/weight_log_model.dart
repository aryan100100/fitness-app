// [HEALTH APP] — Weight Log Model (Feature 7)
// Mirrors the weight_logs Supabase table.

class WeightLog {
  final String? id;
  final String userId;
  final double weightKg;
  final DateTime loggedAt;       // date only (no time component used)
  final bool isMenstrualPhase;
  final String? note;
  final String? createdAt;

  const WeightLog({
    this.id,
    required this.userId,
    required this.weightKg,
    required this.loggedAt,
    this.isMenstrualPhase = false,
    this.note,
    this.createdAt,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      loggedAt: json['logged_at'] != null
          ? DateTime.tryParse(json['logged_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isMenstrualPhase: json['is_menstrual_phase'] as bool? ?? false,
      note: json['note'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'weight_kg': weightKg,
        'logged_at': _dateStr(loggedAt),
        'is_menstrual_phase': isMenstrualPhase,
        if (note != null) 'note': note,
      };

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
