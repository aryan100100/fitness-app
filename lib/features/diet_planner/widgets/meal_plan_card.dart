// [HEALTH APP] — Meal Plan Card Widget
// Displays one PlannedMeal from the AI-generated plan.
// Expandable/collapsible. "Log This Meal" triggers atomic batch insert.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/meal_plan_result.dart';
import '../../../../core/services/diet_planner_service.dart';

class MealPlanCard extends StatefulWidget {
  final PlannedMeal meal;
  final void Function()? onLogged;

  const MealPlanCard({super.key, required this.meal, this.onLogged});

  @override
  State<MealPlanCard> createState() => _MealPlanCardState();
}

class _MealPlanCardState extends State<MealPlanCard> {
  bool _expanded = true;
  bool _logging = false;

  Future<void> _logMeal() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    setState(() => _logging = true);
    try {
      await DietPlannerService.instance.logMealItems(userId, widget.meal);
      if (!mounted) return;
      setState(() => widget.meal.isLogged = true);
      widget.onLogged?.call();
      final mealLabel =
          widget.meal.mealType[0].toUpperCase() + widget.meal.mealType.substring(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mealLabel logged to your diary 🎉',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primaryAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log meal: $e',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                BorderRadius.vertical(top: const Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(meal.mealIcon,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.mealType[0].toUpperCase() +
                              meal.mealType.substring(1),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          meal.mealName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${meal.totalCalories.toInt()} kcal',
                    style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          // Body
          if (_expanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item list
                  ...meal.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13)),
                                ),
                                Text('${item.calories.toInt()} kcal',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            Text(item.quantity,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                            const SizedBox(height: 4),
                            // Macro pills
                            Row(
                              children: [
                                _macroPill(
                                    'P: ${item.protein.toInt()}g',
                                    const Color(0xFF4CAF50)),
                                const SizedBox(width: 6),
                                _macroPill(
                                    'C: ${item.carbs.toInt()}g',
                                    const Color(0xFF2196F3)),
                                const SizedBox(width: 6),
                                _macroPill(
                                    'F: ${item.fat.toInt()}g',
                                    const Color(0xFFFF9800)),
                              ],
                            ),
                          ],
                        ),
                      )),
                  // Prep note
                  if (meal.prepNote.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 ',
                              style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              meal.prepNote,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  // AI disclaimer
                  const Text(
                    'AI Generated — values are estimates',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  // Log button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: (meal.isLogged || _logging) ? null : _logMeal,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: meal.isLogged
                              ? Colors.white24
                              : AppColors.primaryAccent,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _logging
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryAccent)))
                          : Text(
                              meal.isLogged ? '✅ Logged' : 'Log This Meal',
                              style: TextStyle(
                                color: meal.isLogged
                                    ? Colors.white24
                                    : AppColors.primaryAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macroPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}
