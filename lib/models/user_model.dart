// [HEALTH APP] — User Model
// Mirrors the `users` Supabase table exactly.

class UserModel {
  final String? id;
  final String name;
  final int age;
  final String biologicalSex;       // 'male' | 'female'
  final double heightCm;
  final double weightKg;
  final double? targetWeightKg;
  final String goal;                 // 'lose' | 'gain' | 'maintain'
  final String activityLevel;        // 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active'
  final String lifeSituation;        // 'hostel_student' | 'office_worker' | 'work_from_home' | 'homemaker' | 'other'
  final String region;               // 'India' | 'USA' | 'UK' | 'Other'
  final double tdee;
  final double targetCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String? goalStartDate;       // yyyy-MM-dd
  final String? goalEndDate;         // yyyy-MM-dd
  final List<String> foodPreferences;
  final String? createdAt;

  const UserModel({
    this.id,
    required this.name,
    required this.age,
    required this.biologicalSex,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.goal,
    required this.activityLevel,
    required this.lifeSituation,
    this.region = 'India',
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    this.goalStartDate,
    this.goalEndDate,
    this.foodPreferences = const [],
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      biologicalSex: json['biological_sex'] as String? ?? 'male',
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      goal: json['goal'] as String? ?? 'maintain',
      activityLevel: json['activity_level'] as String? ?? 'sedentary',
      lifeSituation: json['life_situation'] as String? ?? 'other',
      region: json['region'] as String? ?? 'India',
      tdee: (json['tdee'] as num?)?.toDouble() ?? 0,
      targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0,
      goalStartDate: json['goal_start_date'] as String?,
      goalEndDate: json['goal_end_date'] as String?,
      foodPreferences: json['food_preferences'] != null
          ? List<String>.from(json['food_preferences'] as List)
          : [],
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'age': age,
      'biological_sex': biologicalSex,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      'goal': goal,
      'activity_level': activityLevel,
      'life_situation': lifeSituation,
      'region': region,
      'tdee': tdee,
      'target_calories': targetCalories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      if (goalStartDate != null) 'goal_start_date': goalStartDate,
      if (goalEndDate != null) 'goal_end_date': goalEndDate,
      'food_preferences': foodPreferences,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    int? age,
    String? biologicalSex,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    String? goal,
    String? activityLevel,
    String? lifeSituation,
    String? region,
    double? tdee,
    double? targetCalories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    String? goalStartDate,
    String? goalEndDate,
    List<String>? foodPreferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      lifeSituation: lifeSituation ?? this.lifeSituation,
      region: region ?? this.region,
      tdee: tdee ?? this.tdee,
      targetCalories: targetCalories ?? this.targetCalories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      goalStartDate: goalStartDate ?? this.goalStartDate,
      goalEndDate: goalEndDate ?? this.goalEndDate,
      foodPreferences: foodPreferences ?? this.foodPreferences,
    );
  }
}
