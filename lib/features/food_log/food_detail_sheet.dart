// [HEALTH APP] — Food Detail Sheet
// Bottom sheet: quantity/unit selector, real-time macro recalculation,
// portion hint, sanity check, accuracy disclaimer, Add button.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/portion_references.dart';
import '../../core/services/streak_service.dart';
import '../../models/food_search_result.dart';
import '../../models/user_model.dart';

class FoodDetailSheet extends StatefulWidget {
  final FoodSearchResult food;
  final String mealType;
  final String mealLabel;
  final UserModel user;

  const FoodDetailSheet({
    super.key,
    required this.food,
    required this.mealType,
    required this.mealLabel,
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

  // Unit → grams multiplier (approximate)
  static const Map<String, double> _unitToGrams = {
    'g':     1.0,
    'oz':    28.35,
    'cup':   240.0,
    'tbsp':  15.0,
    'tsp':   5.0,
    'piece': 100.0,  // overridden by servingSizeG
    'slice': 30.0,
    'bowl':  300.0,
  };

  @override
  void initState() {
    super.initState();
    // Default to food's natural serving size
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
              child: Text('Log it',
                  style: AppTextStyles.captionAccent),
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
        'meal_type':        widget.mealType,
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
    final portionHint =
        PortionReferences.get(widget.food.foodName);
    final isIndian =
        widget.food.source == FoodSource.indianLocal;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Food name
              Text(widget.food.foodName,
                  style: AppTextStyles.headingMedium),
              const SizedBox(height: 4),

              // Source badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.food.sourceLabel,
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ),

              // Indian note
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
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Quantity + unit row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _unit,
                        dropdownColor: AppColors.elevatedCard,
                        style: AppTextStyles.body,
                        items: ['g', 'oz', 'cup', 'tbsp', 'tsp',
                            'piece', 'slice', 'bowl']
                            .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u,
                                    style: AppTextStyles.body)))
                            .toList(),
                        onChanged: _onUnitChanged,
                      ),
                    ),
                  ),
                ],
              ),

              // Portion hint
              if (portionHint != null) ...[
                const SizedBox(height: 8),
                Text('💡 $portionHint',
                    style: AppTextStyles.caption),
              ],

              const SizedBox(height: 24),

              // Calories big number
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

              const SizedBox(height: 16),

              // Macro mini-bars
              _MacroRow(
                  label: 'Protein',
                  value: _protein,
                  color: AppColors.proteinBar),
              const SizedBox(height: 8),
              _MacroRow(
                  label: 'Carbs',
                  value: _carbs,
                  color: AppColors.carbBar),
              const SizedBox(height: 8),
              _MacroRow(
                  label: 'Fat',
                  value: _fat,
                  color: AppColors.fatBar),
              if (_fibre > 0) ...[
                const SizedBox(height: 8),
                _MacroRow(
                    label: 'Fibre',
                    value: _fibre,
                    color: const Color(0xFFB39DDB)),
              ],

              const SizedBox(height: 16),

              // Accuracy disclaimer
              Text(
                '⚠️ Nutritional values are estimates. Actual content may vary by preparation, brand, or portion.',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Add button
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
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black),
                        )
                      : Text(
                          'Add to ${widget.mealLabel}',
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

class _MacroRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: AppTextStyles.caption),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${value.round()}g', style: AppTextStyles.caption),
      ],
    );
  }
}
