// [HEALTH APP] — Streak Milestone Card (Feature 8)
// Celebrates streak milestones gently on the dashboard.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class StreakMilestoneCard extends StatelessWidget {
  final int streakDays;
  final VoidCallback onDismiss;

  const StreakMilestoneCard({
    super.key,
    required this.streakDays,
    required this.onDismiss,
  });

  String get _message {
    if (streakDays >= 90) {
      return "Logging consistently for three months. This is how lasting change happens.";
    } else if (streakDays >= 30) {
      return "30 days 🎯 A whole month of consistent logging. This is how lasting change happens.";
    } else if (streakDays >= 14) {
      return "14-day streak 🔥 Two full weeks of showing up for yourself.";
    } else if (streakDays >= 7) {
      return "7-day streak 🔥 You've logged every day this week — that's a powerful habit.";
    } else {
      return "$streakDays-day streak 🔥 Great momentum keeping at it.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              _message,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 20, color: AppColors.primaryAccent),
          ),
        ],
      ),
    );
  }
}
