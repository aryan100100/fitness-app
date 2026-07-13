// [HEALTH APP] — Food Detail Sheet
// Bottom sheet: meal type chip selector (with smart time-based default),
// quantity/unit selector, real-time macro recalculation, per-100g vs per-serving
// table, portion hint, sanity check, accuracy disclaimer, Add button.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/portion_references.dart';
import '../../core/services/streak_service.dart';
import '../../models/food_search_result.dart';
import '../../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smart time → meal heuristic (matches nav_shell.dart and dashboard)
// ─────────────────────────────────────────────────────────────────────────────
String _smartMealType() {
  final hour = DateTime.now().hour;
  if (hour >= 5  && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 15) return 'lunch';
  if (hour >= 15 && hour < 18) return 'snacks';
  if (hour >= 18 && hour < 23) return 'dinner';
  return 'snacks';
}

String _mealLabel(String mealType) => switch (mealType) {
  'breakfast' => 'Breakfast',
  'lunch'     => 'Lunch',
  'dinner'    => 'Dinner',
  _           => 'Snacks',
};

class FoodDetailSheet extends StatefulWidget {
  final FoodSearchResult food;
  /// Explicit meal type from navigation. If null, falls back to time-based smart default.
  final String? mealType;
  /// Deprecated convenience alias — kept for call-site compatibility.
  final String? mealLabel;
  final UserModel user;

  const FoodDetailSheet({
    super.key,
    required this.food,
    this.mealType,
    this.mealLabel,
    required this.user,
  });

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  final _qtyController = TextEditingController();
  String _unit = 'g';
  double _grams = 100;
  bool _isSaving = false;

  /// The currently selected meal type — driven by chip selector.
  late String _selectedMealType;

  // Unit → grams multiplier (approximate)
  static const Map<String, double> _unitToGrams = {
    'g':     1.0,
    'oz':    28.35,
    'cup':   240.0,
    'tbsp':  15.0,
    'tsp':   5.0,
    'piece': 100.0,
    'slice': 30.0,
    'bowl':  300.0,
  };

  static const _mealTypes = ['breakfast', 'lunch', 'snacks', 'dinner'];

  @override
  void initState() {
    super.initState();
    // Explicit meal type from navigation overrides the time-based guess
    _selectedMealType = widget.mealType ?? _smartMealType();

    final defaultQty = widget.food.servingSizeG;
    _grams = defaultQty;
    _qtyController.text = defaultQty == defaultQty.roundToDouble()
        ? defaultQty.round().toString()
        : defaultQty.toStringAsFixed(1);
    _qtyController.addListener(_onQtyChanged);
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onQtyChanged);
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyChanged() {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final mult = _unit == 'piece'
        ? widget.food.servingSizeG
        : (_unitToGrams[_unit] ?? 1.0);
    setState(() => _grams = qty * mult);
  }

  void _onUnitChanged(String? newUnit) {
    if (newUnit == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final mult = newUnit == 'piece'
        ? widget.food.servingSizeG
        : (_unitToGrams[newUnit] ?? 1.0);
    setState(() {
      _unit = newUnit;
      _grams = qty * mult;
    });
  }

  // Computed macros for current quantity
  double get _calories => widget.food.caloriesForServing(_grams);
  double get _protein  => widget.food.proteinForServing(_grams);
  double get _carbs    => widget.food.carbsForServing(_grams);
  double get _fat      => widget.food.fatForServing(_grams);
  double get _fibre    => widget.food.fibreForServing(_grams);

  Future<void> _addToLog() async {
    // Sanity check: single entry > TDEE + 1000?
    if (_calories > widget.user.tdee + 1000) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: Text('Large entry', style: AppTextStyles.body
              .copyWith(fontWeight: FontWeight.bold)),
          content: Text(
            'That\'s a large entry — just making sure the quantity is right before we log it.',
            style: AppTextStyles.bodySecondary,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Adjust', style: AppTextStyles.caption),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Log it', style: AppTextStyles.captionAccent),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await Supabase.instance.client.from('food_logs').insert({
        'user_id':          userId,
        'date':             dateStr,
        'meal_type':        _selectedMealType,
        'food_name':        widget.food.foodName,
        'quantity_g':       _grams,
        'calories':         _calories,
        'protein_g':        _protein,
        'carbs_g':          _carbs,
        'fat_g':            _fat,
        'fibre_g':          _fibre,
        'food_source':      widget.food.source.name,
        'is_photo_estimate': false,
      });

      try {
        await StreakService.instance.updateStreak(userId, today);
      } catch (e) {
        debugPrint('[STREAK] Error updating streak from detail log: $e');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t save — please try again',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryText)),
            backgroundColor: AppColors.cardSurface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final portionHint = PortionReferences.get(widget.food.foodName);
    final isIndian = widget.food.source == FoodSource.indianLocal;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ───────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Meal type chip selector ───────────────────────────────────
              Text('Adding to:', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Row(
                children: _mealTypes.map((type) {
                  final isSelected = _selectedMealType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMealType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryAccent
                                  : AppColors.divider,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _mealLabel(type),
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? Colors.black
                                    : AppColors.secondaryText,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Food name ─────────────────────────────────────────────────
              Text(widget.food.foodName, style: AppTextStyles.headingMedium),
              const SizedBox(height: 6),

              // ── Source badge ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.food.sourceLabel,
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ),

              // ── Indian home-cooking note ──────────────────────────────────
              if (isIndian) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Home cooking varies. Adjust for oil used and portion size.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Quantity + unit row ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        labelStyle: AppTextStyles.caption,
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _unit,
                        dropdownColor: AppColors.elevatedCard,
                        style: AppTextStyles.body,
                        items: ['g', 'oz', 'cup', 'tbsp', 'tsp', 'piece', 'slice', 'bowl']
                            .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u, style: AppTextStyles.body)))
                            .toList(),
                        onChanged: _onUnitChanged,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Portion hint ──────────────────────────────────────────────
              if (portionHint != null) ...[
                const SizedBox(height: 8),
                Text('💡 $portionHint', style: AppTextStyles.caption),
              ],

              const SizedBox(height: 24),

              // ── Calories big number ───────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      '${_calories.round()}',
                      style: AppTextStyles.statsNumberLarge.copyWith(
                          color: AppColors.primaryAccent),
                    ),
                    Text('kcal', style: AppTextStyles.caption),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Nutrition table: per 100g vs you get ─────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        SizedBox(
                          width: 80,
                          child: Text('Per 100g',
                              style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text('You get',
                              style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryAccent),
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 8),
                    _NutrientRow('Calories',
                        widget.food.caloriesPer100g, _calories,
                        unit: 'kcal', color: AppColors.primaryAccent),
                    _NutrientRow('Protein',
                        widget.food.proteinPer100g, _protein,
                        color: AppColors.proteinBar),
                    _NutrientRow('Carbs',
                        widget.food.carbsPer100g, _carbs,
                        color: AppColors.carbBar),
                    _NutrientRow('Fat',
                        widget.food.fatPer100g, _fat,
                        color: AppColors.fatBar),
                    if (widget.food.fibrePer100g > 0)
                      _NutrientRow('Fibre',
                          widget.food.fibrePer100g, _fibre,
                          color: const Color(0xFFB39DDB)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Accuracy disclaimer ───────────────────────────────────────
              Text(
                '⚠️ Nutritional values are estimates. Actual content may vary by preparation, brand, or portion.',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ── Add button (label updates live with chip selection) ───────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _addToLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'Add to ${_mealLabel(_selectedMealType)}',
                          style: AppTextStyles.buttonLabel.copyWith(
                              color: Colors.black),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nutrient row — per 100g | per serving side-by-side
// ─────────────────────────────────────────────────────────────────────────────
class _NutrientRow extends StatelessWidget {
  final String label;
  final double per100;
  final double forServing;
  final Color color;
  final String unit;

  const _NutrientRow(
    this.label,
    this.per100,
    this.forServing, {
    this.color = const Color(0xFF9E9E9E),
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${per100.round()} $unit',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${forServing.round()} $unit',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
