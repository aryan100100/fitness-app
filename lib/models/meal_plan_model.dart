// [HEALTH APP] — Meal Plan Model

class MealPlanModel {
  final String? id;
  final String userId;
  final String date;
  final Map<String, dynamic> planData;
  final String? createdAt;

  const MealPlanModel({
    this.id,
    required this.userId,
    required this.date,
    required this.planData,
    this.createdAt,
  });

  factory MealPlanModel.fromJson(Map<String, dynamic> json) {
    return MealPlanModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      planData: json['plan_data'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'plan_data': planData,
    };
  }
}
