// [ZCTM] — Plate Method & Photo Protein Models
// Plate method: user taps zones on a visual divided plate.
// Photo protein: multimodal call using an image + structured prompt.

/// Adequacy classification for a meal's protein content.
enum ProteinAdequacy { adequate, borderline, inadequate }

extension ProteinAdequacyX on ProteinAdequacy {
  static ProteinAdequacy fromString(String s) => switch (s) {
        'adequate' => ProteinAdequacy.adequate,
        'borderline' => ProteinAdequacy.borderline,
        _ => ProteinAdequacy.inadequate,
      };
}

// ---------------------------------------------------------------------------
// PLATE METHOD (text-based zone tapping)
// ---------------------------------------------------------------------------

/// Foods the user assigned to each plate zone.
class PlateInput {
  final List<String> proteinZoneFoods;  // quarter plate — the protein source
  final List<String> vegZoneFoods;      // half plate — vegetables / salad
  final List<String> grainZoneFoods;    // quarter plate — carbs / grains
  final List<String> extraZoneFoods;    // optional extras (sauce, fruit, drink)
  final double perMealProteinTargetG;
  final String mealType;               // breakfast | lunch | dinner | snack
  final String lifeSituation;

  const PlateInput({
    required this.proteinZoneFoods,
    required this.vegZoneFoods,
    required this.grainZoneFoods,
    required this.extraZoneFoods,
    required this.perMealProteinTargetG,
    required this.mealType,
    required this.lifeSituation,
  });

  Map<String, dynamic> toJson() => {
        'protein_zone_foods': proteinZoneFoods,
        'veg_zone_foods': vegZoneFoods,
        'grain_zone_foods': grainZoneFoods,
        'extra_zone_foods': extraZoneFoods,
        'per_meal_protein_target_g': perMealProteinTargetG,
        'meal_type': mealType,
        'life_situation': lifeSituation,
      };
}

/// Result returned by Gemini for a plate method inference.
class PlateInferenceResult {
  final double estimatedProteinG;
  final ProteinAdequacy adequacy;
  final String confirmationMessage; // 1 sentence, warm, food-specific

  const PlateInferenceResult({
    required this.estimatedProteinG,
    required this.adequacy,
    required this.confirmationMessage,
  });

  factory PlateInferenceResult.fromJson(Map<String, dynamic> j) =>
      PlateInferenceResult(
        estimatedProteinG: (j['estimated_protein_g'] as num?)?.toDouble() ?? 0,
        adequacy: ProteinAdequacyX.fromString(
            j['adequacy'] as String? ?? 'inadequate'),
        confirmationMessage: j['confirmation_message'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// PHOTO PROTEIN ADEQUACY (multimodal — image + JSON context)
// ---------------------------------------------------------------------------

/// Result returned by Gemini when analysing a meal photo for protein content.
class PhotoProteinResult {
  final List<String> identifiedFoods;
  final double estimatedProteinG;
  final ProteinAdequacy adequacy;
  final String confirmationMessage;
  final String confidenceLevel; // 'high' | 'medium' | 'low'

  const PhotoProteinResult({
    required this.identifiedFoods,
    required this.estimatedProteinG,
    required this.adequacy,
    required this.confirmationMessage,
    required this.confidenceLevel,
  });

  factory PhotoProteinResult.fromJson(Map<String, dynamic> j) =>
      PhotoProteinResult(
        identifiedFoods:
            List<String>.from(j['identified_foods'] as List? ?? []),
        estimatedProteinG:
            (j['estimated_protein_g'] as num?)?.toDouble() ?? 0,
        adequacy: ProteinAdequacyX.fromString(
            j['adequacy'] as String? ?? 'inadequate'),
        confirmationMessage: j['confirmation_message'] as String? ?? '',
        confidenceLevel: j['confidence_level'] as String? ?? 'low',
      );
}
