// [HEALTH APP] — Workout Model
// Represents a single workout session (e.g. "Push Day", "Morning Run").
// Each workout contains multiple exercise sets stored in separate table.

class WorkoutModel {
  final String? id;
  final String userId;
  final String date;           // yyyy-MM-dd
  final String name;           // e.g. "Push Day", "Cardio", "Full Body"
  final String type;           // 'strength' | 'cardio' | 'flexibility' | 'sports'
  final int durationMinutes;   // total workout duration
  final String? notes;
  final String? createdAt;

  const WorkoutModel({
    this.id,
    required this.userId,
    required this.date,
    required this.name,
    required this.type,
    required this.durationMinutes,
    this.notes,
    this.createdAt,
  });

  factory WorkoutModel.fromJson(Map<String, dynamic> json) {
    return WorkoutModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'strength',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'name': name,
      'type': type,
      'duration_minutes': durationMinutes,
      'notes': notes,
    };
  }
}
