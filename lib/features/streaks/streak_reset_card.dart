// [HEALTH APP] — Streak Reset Card (Feature 8)
// Sent gentle message when a streak resets. Follows Fresh Start Effect research.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class StreakResetCard extends StatelessWidget {
  final VoidCallback onDismiss;

  const StreakResetCard({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isMonday = now.weekday == DateTime.monday;
    
    final message = isMonday
        ? "New week, new streak — let's go."
        : "Fresh start from today.";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Streak reset — and that\'s okay. 👋',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, size: 20, color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Today is a fresh start. Every consistent logger has had breaks.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                message,
                style: AppTextStyles.captionAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
