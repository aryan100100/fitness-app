// [HEALTH APP] — Daily Summary Card
// Shows the total macros for the AI-generated day plan and compares to target.

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/meal_plan_result.dart';
import '../../../../models/user_model.dart';

class DailySummaryCard extends StatelessWidget {
  final MealPlanResult plan;
  final UserModel user;

  const DailySummaryCard({super.key, required this.plan, required this.user});

  @override
  Widget build(BuildContext context) {
    final ratio = user.targetCalories > 0
        ? plan.totalCalories / user.targetCalories
        : 0.0;
    final onTarget = (ratio - 1.0).abs() <= 0.05;
    final statusColor =
        onTarget ? AppColors.primaryAccent : const Color(0xFFFFA726);
    final statusText = onTarget
        ? 'On target ✓'
        : 'Adjust portions to hit your target';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Total',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // Macro grid
          Row(
            children: [
              _macroCol('Calories', '${plan.totalCalories.toInt()}',
                  'kcal', AppColors.primaryAccent),
              _macroCol('Protein', '${plan.totalProtein.toInt()}',
                  'g', const Color(0xFF4CAF50)),
              _macroCol('Carbs', '${plan.totalCarbs.toInt()}',
                  'g', const Color(0xFF2196F3)),
              _macroCol('Fat', '${plan.totalFat.toInt()}',
                  'g', const Color(0xFFFF9800)),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          Text(
            'Plan provides ${plan.totalCalories.toInt()} kcal of your '
            '${user.targetCalories.toInt()} kcal target',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.2),
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                onTarget
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: statusColor,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AI Generated — values are estimates',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _macroCol(
      String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          Text(unit,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
