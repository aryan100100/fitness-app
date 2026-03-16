// [HEALTH APP] — Barcode Product Models (Feature 10)
// BarcodeProduct, BarcodeResult, ConfidenceLevel

enum ConfidenceLevel { high, medium, low }

class BarcodeProduct {
  final String? barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double? fibrePer100g;
  final double? servingSizeG;
  final String source; // 'off' | 'indian_db' | 'nutritionix' | 'user_saved'
  final ConfidenceLevel confidence;

  const BarcodeProduct({
    this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fibrePer100g,
    this.servingSizeG,
    required this.source,
    required this.confidence,
  });

  /// Nutrition scaled to [grams]g
  Map<String, double> nutritionFor(double grams) {
    final factor = grams / 100.0;
    return {
      'calories': caloriesPer100g * factor,
      'protein_g': proteinPer100g * factor,
      'carbs_g': carbsPer100g * factor,
      'fat_g': fatPer100g * factor,
      'fibre_g': (fibrePer100g ?? 0.0) * factor,
    };
  }

  BarcodeProduct copyWith({
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fibrePer100g,
    double? servingSizeG,
  }) {
    return BarcodeProduct(
      barcode: barcode,
      name: name,
      brand: brand,
      imageUrl: imageUrl,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      fibrePer100g: fibrePer100g ?? this.fibrePer100g,
      servingSizeG: servingSizeG ?? this.servingSizeG,
      source: source,
      confidence: confidence,
    );
  }

  factory BarcodeProduct.fromOff(Map<String, dynamic> product, ConfidenceLevel conf) {
    final n = product['nutriments'] as Map<String, dynamic>? ?? {};
    return BarcodeProduct(
      barcode: product['code'] as String?,
      name: (product['product_name'] as String? ?? '').trim(),
      brand: product['brands'] as String?,
      imageUrl: product['image_front_url'] as String?,
      caloriesPer100g: _d(n['energy-kcal_100g']),
      proteinPer100g: _d(n['proteins_100g']),
      carbsPer100g: _d(n['carbohydrates_100g']),
      fatPer100g: _d(n['fat_100g']),
      fibrePer100g: _d(n['fiber_100g']),
      servingSizeG: _d(product['serving_quantity']),
      source: 'off',
      confidence: conf,
    );
  }

  factory BarcodeProduct.fromIndianDb(Map<String, dynamic> entry) {
    final p = entry['per_100g'] as Map<String, dynamic>;
    return BarcodeProduct(
      barcode: entry['barcode'] as String?,
      name: entry['name'] as String,
      brand: entry['brand'] as String?,
      caloriesPer100g: _d(p['calories']),
      proteinPer100g: _d(p['protein_g']),
      carbsPer100g: _d(p['carbs_g']),
      fatPer100g: _d(p['fat_g']),
      fibrePer100g: _d(p['fibre_g']),
      servingSizeG: _d(entry['serving_size_g']),
      source: 'indian_db',
      confidence: ConfidenceLevel.high,
    );
  }

  factory BarcodeProduct.fromNutritionix(Map<String, dynamic> item) {
    return BarcodeProduct(
      barcode: item['upc'] as String?,
      name: item['food_name'] as String? ?? '',
      brand: item['brand_name'] as String?,
      imageUrl: item['photo']?['thumb'] as String?,
      caloriesPer100g: _d(item['nf_calories']),
      proteinPer100g: _d(item['nf_protein']),
      carbsPer100g: _d(item['nf_total_carbohydrate']),
      fatPer100g: _d(item['nf_total_fat']),
      fibrePer100g: _d(item['nf_dietary_fiber']),
      servingSizeG: _d(item['serving_weight_grams']),
      source: 'nutritionix',
      confidence: ConfidenceLevel.medium,
    );
  }

  factory BarcodeProduct.fromCustomFood(Map<String, dynamic> row) {
    return BarcodeProduct(
      barcode: row['barcode'] as String?,
      name: row['name'] as String,
      caloriesPer100g: _d(row['calories_per_100g']),
      proteinPer100g: _d(row['protein_per_100g']),
      carbsPer100g: _d(row['carbs_per_100g']),
      fatPer100g: _d(row['fat_per_100g']),
      fibrePer100g: _d(row['fibre_per_100g']),
      servingSizeG: _d(row['serving_size_g']),
      source: 'user_saved',
      confidence: ConfidenceLevel.high,
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    return (v as num).toDouble();
  }
}

class BarcodeResult {
  final BarcodeProduct? product;
  final bool found;
  final String source; // 'off' | 'indian_db' | 'nutritionix' | 'user_saved' | 'not_found'
  final ConfidenceLevel confidence;

  const BarcodeResult({
    this.product,
    required this.found,
    required this.source,
    required this.confidence,
  });

  factory BarcodeResult.notFound() => const BarcodeResult(
        found: false,
        source: 'not_found',
        confidence: ConfidenceLevel.low,
      );
}
