// [HEALTH APP] — Streak Widget (Feature 8)
// Displays the current streak and 7-day visual calendar on the dashboard.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/streak_service.dart';
import '../../models/streak_model.dart';

class StreakWidget extends StatelessWidget {
  final StreakModel streak;
  final List<DayStatus> last7Days;

  const StreakWidget({
    super.key,
    required this.streak,
    required this.last7Days,
  });

  @override
  Widget build(BuildContext context) {
    if (streak.streakHidden) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                '${streak.currentStreak} day streak',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: last7Days.map((status) => _buildDot(status)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(DayStatus status) {
    Color color;
    bool isStroked = false;

    switch (status) {
      case DayStatus.logged:
        color = AppColors.primaryAccent;
        break;
      case DayStatus.grace:
        color = AppColors.secondaryText;
        break;
      case DayStatus.unlogged:
        color = AppColors.destructive;
        break;
      case DayStatus.future:
        color = AppColors.divider;
        isStroked = true;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isStroked ? Colors.transparent : color,
        shape: BoxShape.circle,
        border: isStroked ? Border.all(color: color, width: 2) : null,
      ),
    );
  }
}
