// [HEALTH APP] — Barcode Result Screen (Feature 10)
// Phase 5: Confirmation + portion picker. The critical screen for accuracy.
// Always shows per 100g AND live-calculated values. Always requires confirmation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/streak_service.dart';
import '../../models/barcode_product_model.dart';
import '../../models/user_model.dart';

class BarcodeResultScreen extends StatefulWidget {
  final BarcodeProduct product;
  final String mealType;
  final UserModel user;

  const BarcodeResultScreen({
    super.key,
    required this.product,
    required this.mealType,
    required this.user,
  });

  @override
  State<BarcodeResultScreen> createState() => _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends State<BarcodeResultScreen> {
  // ── Portion state ──────────────────────────────────────────────────────────
  double _gramsSelected = 100.0;
  bool _useServings = false;
  double _servingMultiplier = 1.0;
  final _gramsController = TextEditingController();
  final _servingsController = TextEditingController();

  // ── Override state ─────────────────────────────────────────────────────────
  bool _editExpanded = false;
  late double _editCalories;
  late double _editProtein;
  late double _editCarbs;
  late double _editFat;
  late double _editFibre;

  bool _isSaving = false;
  late BarcodeProduct _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;

    final serving = _product.servingSizeG ?? 100.0;
    _gramsSelected = serving;
    _gramsController.text = _gramsSelected.round().toString();
    _servingsController.text = '1';

    _resetEditFields();
  }

  void _resetEditFields() {
    final n = _product.nutritionFor(_gramsSelected);
    _editCalories = n['calories']!;
    _editProtein = n['protein_g']!;
    _editCarbs = n['carbs_g']!;
    _editFat = n['fat_g']!;
    _editFibre = n['fibre_g']!;
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  // ── Computed nutrition at current grams ────────────────────────────────────
  Map<String, double> get _liveNutrition =>
      _editExpanded ? {
        'calories': _editCalories,
        'protein_g': _editProtein,
        'carbs_g': _editCarbs,
        'fat_g': _editFat,
        'fibre_g': _editFibre,
      } : _product.nutritionFor(_gramsSelected);

  String get _mealLabel {
    switch (widget.mealType) {
      case 'breakfast': return 'Breakfast';
      case 'lunch': return 'Lunch';
      case 'dinner': return 'Dinner';
      default: return 'Snack';
    }
  }

  void _setGrams(double g) {
    setState(() {
      _gramsSelected = g;
      _gramsController.text = g.round().toString();
      if (_product.servingSizeG != null && _product.servingSizeG! > 0) {
        _servingMultiplier = g / _product.servingSizeG!;
        _servingsController.text = _servingMultiplier.toStringAsFixed(1);
      }
      _resetEditFields();
    });
  }

  void _onGramsChanged(String val) {
    final g = double.tryParse(val) ?? _gramsSelected;
    setState(() {
      _gramsSelected = g;
      if (_product.servingSizeG != null && _product.servingSizeG! > 0) {
        _servingMultiplier = g / _product.servingSizeG!;
        _servingsController.text = _servingMultiplier.toStringAsFixed(1);
      }
      _resetEditFields();
    });
  }

  void _onServingsChanged(String val) {
    final s = double.tryParse(val) ?? 1.0;
    final serving = _product.servingSizeG ?? 100.0;
    setState(() {
      _servingMultiplier = s;
      _gramsSelected = s * serving;
      _gramsController.text = _gramsSelected.round().toString();
      _resetEditFields();
    });
  }

  // ── Confidence badge ───────────────────────────────────────────────────────
  Widget _confidenceBadge() {
    Color bg;
    Color text;
    String label;

    switch (_product.confidence) {
      case ConfidenceLevel.high:
        bg = const Color(0xFF1B5E20);
        text = const Color(0xFF69F0AE);
        label = '📋 Official label';
        break;
      case ConfidenceLevel.medium:
        bg = const Color(0xFF4E3000);
        text = AppColors.warning;
        label = '👥 Community data — please check your label';
        break;
      case ConfidenceLevel.low:
        bg = const Color(0xFF4E1515);
        text = const Color(0xFFFF6B6B);
        label = '⚠️ Incomplete data — please verify';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(color: text)),
    );
  }

  // ── Log the food ───────────────────────────────────────────────────────────
  Future<void> _addToLog() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final n = _liveNutrition;

      await Supabase.instance.client.from('food_logs').insert({
        'user_id': userId,
        'date': dateStr,
        'meal_type': widget.mealType,
        'food_name': _product.name,
        'quantity_g': _gramsSelected,
        'calories': n['calories'],
        'protein_g': n['protein_g'],
        'carbs_g': n['carbs_g'],
        'fat_g': n['fat_g'],
        'fibre_g': n['fibre_g'],
        'food_source': 'barcode_scan',
        'is_photo_estimate': false,
      });

      try {
        await StreakService.instance.updateStreak(userId, today);
      } catch (e) {
        debugPrint('[STREAK] Barcode log streak error: $e');
      }

      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Couldn't save — please try again",
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primaryText)),
          backgroundColor: AppColors.cardSurface,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p100 = _product;
    final hasServing = p100.servingSizeG != null && p100.servingSizeG! > 0;
    final serving = p100.servingSizeG ?? 100.0;
    final n = _liveNutrition;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.primaryText,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Confirm Product', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product image + header ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: p100.imageUrl != null
                      ? Image.network(p100.imageUrl!,
                          width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _imagePlaceholder())
                      : _imagePlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p100.name,
                          style: AppTextStyles.headingMedium
                              .copyWith(fontSize: 16),
                          maxLines: 3),
                      if (p100.brand != null) ...[
                        const SizedBox(height: 4),
                        Text(p100.brand!,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.secondaryText)),
                      ],
                      const SizedBox(height: 8),
                      _confidenceBadge(),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Per 100g reference card ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Per 100g (reference)',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.secondaryText)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _per100Cell('Cal', '${p100.caloriesPer100g.round()} kcal'),
                    _per100Cell('Protein', '${p100.proteinPer100g.toStringAsFixed(1)}g'),
                    _per100Cell('Carbs', '${p100.carbsPer100g.toStringAsFixed(1)}g'),
                    _per100Cell('Fat', '${p100.fatPer100g.toStringAsFixed(1)}g'),
                  ]),
                  if (p100.fibrePer100g != null) ...[
                    const SizedBox(height: 6),
                    Text('Fibre: ${p100.fibrePer100g!.toStringAsFixed(1)}g',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.secondaryText)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text('How much did you eat?',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            // ── Quick-select buttons ───────────────────────────────────────
            if (hasServing)
              Row(children: [
                _quickBtn('½ serving\n(${(serving / 2).round()}g)',
                    serving / 2),
                const SizedBox(width: 8),
                _quickBtn('1 serving\n(${serving.round()}g)', serving,
                    isDefault: true),
                const SizedBox(width: 8),
                _quickBtn('Whole pack\n(${(serving * 3).round()}g)',
                    serving * 3),
              ]),

            const SizedBox(height: 14),

            // ── Gram / servings input ──────────────────────────────────────
            Row(children: [
              Expanded(
                child: _useServings
                    ? _numField(
                        controller: _servingsController,
                        label: 'Servings',
                        onChanged: _onServingsChanged)
                    : _numField(
                        controller: _gramsController,
                        label: 'Grams',
                        onChanged: _onGramsChanged),
              ),
              const SizedBox(width: 10),
              if (hasServing)
                ToggleButtons(
                  isSelected: [!_useServings, _useServings],
                  onPressed: (i) =>
                      setState(() => _useServings = i == 1),
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.black,
                  fillColor: AppColors.primaryAccent,
                  color: AppColors.secondaryText,
                  borderColor: AppColors.divider,
                  selectedBorderColor: AppColors.primaryAccent,
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('g', style: TextStyle(fontSize: 13)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('srv', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
            ]),

            if (_useServings && hasServing) ...[
              const SizedBox(height: 6),
              Text(
                '${_servingMultiplier.toStringAsFixed(1)} servings = ${_gramsSelected.round()}g',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondaryText),
              ),
            ],

            const SizedBox(height: 16),

            // ── Live calculation card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2E1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You'll log",
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primaryAccent)),
                  const SizedBox(height: 8),
                  Text(
                    '${n['calories']!.round()} kcal',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${n['protein_g']!.toStringAsFixed(1)}g protein  •  '
                    '${n['carbs_g']!.toStringAsFixed(1)}g carbs  •  '
                    '${n['fat_g']!.toStringAsFixed(1)}g fat  •  '
                    '${n['fibre_g']!.toStringAsFixed(1)}g fibre',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primaryText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Edit values expander ───────────────────────────────────────
            GestureDetector(
              onTap: () =>
                  setState(() => _editExpanded = !_editExpanded),
              child: Row(children: [
                Icon(
                    _editExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.edit_outlined,
                    size: 15,
                    color: AppColors.secondaryText),
                const SizedBox(width: 4),
                Text('Edit nutrition values manually',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.secondaryText,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.secondaryText)),
              ]),
            ),

            if (_editExpanded) ...[
              const SizedBox(height: 10),
              _editField('Calories (kcal)', _editCalories,
                  (v) => setState(() => _editCalories = v)),
              _editField('Protein (g)', _editProtein,
                  (v) => setState(() => _editProtein = v)),
              _editField('Carbs (g)', _editCarbs,
                  (v) => setState(() => _editCarbs = v)),
              _editField('Fat (g)', _editFat,
                  (v) => setState(() => _editFat = v)),
              _editField('Fibre (g)', _editFibre,
                  (v) => setState(() => _editFibre = v)),
            ],

            const SizedBox(height: 16),

            // ── Disclaimer ─────────────────────────────────────────────────
            Text(
              'Nutrition values are from the product label. Labels can vary by '
              '±10–20% from actual content — we account for this through your '
              'weekly weight trend.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.secondaryText, fontSize: 11),
            ),

            const SizedBox(height: 24),

            // ── Add to meal button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addToLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text('Add to $_mealLabel',
                        style: AppTextStyles.buttonLabel),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _imagePlaceholder() => Container(
        width: 80,
        height: 80,
        color: AppColors.cardSurface,
        child: const Icon(Icons.fastfood_outlined,
            color: AppColors.secondaryText, size: 32),
      );

  Widget _per100Cell(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: AppColors.secondaryText)),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ]),
      );

  Widget _quickBtn(String label, double grams,
      {bool isDefault = false}) =>
      Expanded(
        child: GestureDetector(
          onTap: () => _setGrams(grams),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ((_gramsSelected - grams).abs() < 1 || isDefault && (_gramsSelected - grams).abs() < 1)
                  ? AppColors.primaryAccent.withValues(alpha: 0.15)
                  : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (_gramsSelected - grams).abs() < 1
                      ? AppColors.primaryAccent
                      : AppColors.divider),
            ),
            alignment: Alignment.center,
            child: Text(label,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                    color: (_gramsSelected - grams).abs() < 1
                        ? AppColors.primaryAccent
                        : AppColors.primaryText,
                    fontSize: 11,
                    height: 1.5)),
          ),
        ),
      );

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) =>
      TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
        ],
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.caption,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColors.primaryAccent, width: 1.5)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _editField(
          String label, double value, ValueChanged<double> onSet) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller:
              TextEditingController(text: value.toStringAsFixed(1)),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          ],
          onChanged: (v) {
            final d = double.tryParse(v);
            if (d != null) onSet(d);
          },
          style: AppTextStyles.body,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AppTextStyles.caption,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primaryAccent, width: 1.5)),
          ),
        ),
      );
}
