// [HEALTH APP] — Barcode Not Found Screen (Feature 10)
// Shown when barcode lookup fails in all 4 tiers.
// User enters values from the nutrition label on their pack.
// Optionally saved to personal foods DB with barcode for instant future lookup.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/streak_service.dart';
import '../../models/barcode_product_model.dart';
import '../../models/user_model.dart';

class BarcodeNotFoundScreen extends StatefulWidget {
  final String barcode;
  final String mealType;
  final UserModel user;

  const BarcodeNotFoundScreen({
    super.key,
    required this.barcode,
    required this.mealType,
    required this.user,
  });

  @override
  State<BarcodeNotFoundScreen> createState() => _BarcodeNotFoundScreenState();
}

class _BarcodeNotFoundScreenState extends State<BarcodeNotFoundScreen> {
  final _nameController = TextEditingController();
  final _servingController = TextEditingController(text: '100');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fibreController = TextEditingController();

  bool _saveToPersonal = true;
  bool _isSaving = false;

  String get _mealLabel {
    switch (widget.mealType) {
      case 'breakfast': return 'Breakfast';
      case 'lunch': return 'Lunch';
      case 'dinner': return 'Dinner';
      default: return 'Snack';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fibreController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      double.tryParse(_caloriesController.text) != null &&
      double.tryParse(_proteinController.text) != null &&
      double.tryParse(_carbsController.text) != null &&
      double.tryParse(_fatController.text) != null;

  Future<void> _addToLog() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill in all required fields',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.primaryText)),
        backgroundColor: AppColors.cardSurface,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final servingG = double.tryParse(_servingController.text) ?? 100.0;
      final calories = double.tryParse(_caloriesController.text) ?? 0;
      final protein = double.tryParse(_proteinController.text) ?? 0;
      final carbs = double.tryParse(_carbsController.text) ?? 0;
      final fat = double.tryParse(_fatController.text) ?? 0;
      final fibre = double.tryParse(_fibreController.text) ?? 0;

      // Values entered are per serving — scale to per 100g for storage
      final factor100 = servingG > 0 ? 100.0 / servingG : 1.0;

      if (_saveToPersonal) {
        final product = BarcodeProduct(
          barcode: widget.barcode,
          name: _nameController.text.trim(),
          caloriesPer100g: calories * factor100,
          proteinPer100g: protein * factor100,
          carbsPer100g: carbs * factor100,
          fatPer100g: fat * factor100,
          fibrePer100g: fibre * factor100,
          servingSizeG: servingG,
          source: 'user_saved',
          confidence: ConfidenceLevel.high,
        );
        await BarcodeService.instance.saveUserProduct(userId, product);
      }

      // Log the actual serving the user had
      await Supabase.instance.client.from('food_logs').insert({
        'user_id': userId,
        'date': dateStr,
        'meal_type': widget.mealType,
        'food_name': _nameController.text.trim(),
        'quantity_g': servingG,
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
        'fibre_g': fibre,
        'food_source': 'barcode_scan',
        'is_photo_estimate': false,
      });

      try {
        await StreakService.instance.updateStreak(userId, today);
      } catch (e) {
        debugPrint('[STREAK] Not found screen streak error: $e');
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
        title: Text('Product Not Found', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Text('Product not found 🔍',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            Text(
              "This product isn't in our database yet. Enter the values "
              "from the nutrition label on the back of the pack.",
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Barcode: ${widget.barcode}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondaryText),
              ),
            ),

            const SizedBox(height: 24),
            Text('From the nutrition label',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            // ── Form fields ────────────────────────────────────────────────
            _field('Product name *', _nameController,
                hint: 'e.g. Amul Cheese Slices'),
            _field('Serving size (grams) *', _servingController,
                hint: 'e.g. 30', numeric: true),

            const SizedBox(height: 8),
            Text('Per serving values',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondaryText)),
            const SizedBox(height: 8),

            _field('Calories (kcal) *', _caloriesController,
                hint: 'e.g. 120', numeric: true),
            _field('Protein (g) *', _proteinController,
                hint: 'e.g. 7.0', numeric: true),
            _field('Carbohydrates (g) *', _carbsController,
                hint: 'e.g. 2.5', numeric: true),
            _field('Fat (g) *', _fatController,
                hint: 'e.g. 8.5', numeric: true),
            _field('Fibre (g)', _fibreController,
                hint: 'Optional', numeric: true, required: false),

            const SizedBox(height: 16),

            // ── Save to personal foods toggle ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Save to my personal foods',
                          style: AppTextStyles.body
                              .copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(
                          'Next time you scan this barcode, it loads instantly',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.secondaryText)),
                    ],
                  ),
                ),
                Switch(
                  value: _saveToPersonal,
                  onChanged: (v) =>
                      setState(() => _saveToPersonal = v),
                  activeColor: AppColors.primaryAccent,
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Add button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addToLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
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

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    bool numeric = false,
    bool required = true,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : [],
          style: AppTextStyles.body,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AppTextStyles.caption,
            hintText: hint,
            hintStyle: AppTextStyles.caption
                .copyWith(color: AppColors.secondaryText.withValues(alpha: 0.6)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primaryAccent, width: 1.5)),
          ),
        ),
      );
}
