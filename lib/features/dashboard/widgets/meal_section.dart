// [HEALTH APP] — Meal Section Widget
// Collapsible meal section: header, items list, Dismissible delete, empty state.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/food_log_model.dart';
import '../dashboard_provider.dart';
import 'package:provider/provider.dart';

class MealSection extends StatefulWidget {
  final String mealType;   // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final List<FoodLogModel> logs;
  final VoidCallback onAddTap;

  const MealSection({
    super.key,
    required this.mealType,
    required this.logs,
    required this.onAddTap,
  });

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  bool _isExpanded = true;

  String get _mealLabel {
    return switch (widget.mealType) {
      'breakfast' => 'Breakfast',
      'lunch'     => 'Lunch',
      'dinner'    => 'Dinner',
      _           => 'Snacks',
    };
  }

  String get _mealEmoji {
    return switch (widget.mealType) {
      'breakfast' => '☀️',
      'lunch'     => '🥗',
      'dinner'    => '🍽️',
      _           => '🍎',
    };
  }

  double get _totalCalories =>
      widget.logs.fold(0, (sum, l) => sum + l.calories);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(_mealEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    _mealLabel,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (_totalCalories > 0)
                    Text(
                      '${_totalCalories.round()} kcal',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Add button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onAddTap();
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add,
                          color: AppColors.primaryAccent, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chevron
                  AnimatedRotation(
                    turns: _isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.secondaryText, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // Expandable body
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
                    children: [
                      Divider(
                          color: AppColors.divider, height: 1, thickness: 1),
                      if (widget.logs.isEmpty)
                        _EmptyMealState(mealLabel: _mealLabel,
                            onAddTap: widget.onAddTap)
                      else
                        ...widget.logs.map(
                            (log) => _FoodLogItem(log: log,
                                mealType: widget.mealType)),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single food log item (Dismissible for delete)
// ---------------------------------------------------------------------------
class _FoodLogItem extends StatelessWidget {
  final FoodLogModel log;
  final String mealType;

  const _FoodLogItem({required this.log, required this.mealType});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(log.id ?? log.foodName),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.15),
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16)),
        ),
        child: const Icon(Icons.delete_outline,
            color: AppColors.destructive, size: 22),
      ),
      onDismissed: (_) {
        if (log.id != null) {
          context
              .read<DashboardProvider>()
              .deleteFoodLog(log.id!, mealType);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.foodName,
                      style: AppTextStyles.body.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  // Macro pills
                  Row(
                    children: [
                      _MacroPill('P', '${log.proteinG.round()}g',
                          AppColors.proteinBar),
                      const SizedBox(width: 6),
                      _MacroPill('C', '${log.carbsG.round()}g',
                          AppColors.carbBar),
                      const SizedBox(width: 6),
                      _MacroPill('F', '${log.fatG.round()}g',
                          AppColors.fatBar),
                      if (log.isPhotoEstimate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 10, color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text('AI',
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.warning,
                                          fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${log.calories.round()} kcal',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text('${log.quantityG.round()}g',
                    style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String letter;
  final String value;
  final Color color;

  const _MacroPill(this.letter, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$letter: $value',
        style: AppTextStyles.caption.copyWith(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty meal state
// ---------------------------------------------------------------------------
class _EmptyMealState extends StatelessWidget {
  final String mealLabel;
  final VoidCallback onAddTap;

  const _EmptyMealState(
      {required this.mealLabel, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline,
                color: AppColors.secondaryText, size: 18),
            const SizedBox(width: 8),
            Text(
              'Tap to log your $mealLabel',
              style: AppTextStyles.caption.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
