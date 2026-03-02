// [HEALTH APP] — Food Log Model
// Mirrors the `food_logs` Supabase table exactly.

class FoodLogModel {
  final String? id;
  final String userId;
  final String date;          // yyyy-MM-dd
  final String mealType;      // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String foodName;
  final double quantityG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final bool isPhotoEstimate;
  final String? createdAt;

  const FoodLogModel({
    this.id,
    required this.userId,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.quantityG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.isPhotoEstimate = false,
    this.createdAt,
  });

  factory FoodLogModel.fromJson(Map<String, dynamic> json) {
    return FoodLogModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      mealType: json['meal_type'] as String? ?? 'snack',
      foodName: json['food_name'] as String? ?? '',
      quantityG: (json['quantity_g'] as num?)?.toDouble() ?? 0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      isPhotoEstimate: json['is_photo_estimate'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'meal_type': mealType,
      'food_name': foodName,
      'quantity_g': quantityG,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'is_photo_estimate': isPhotoEstimate,
    };
  }
}
