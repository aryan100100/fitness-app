// [HEALTH APP] — Values Reminder Card (Feature 8)
// Appears after a user selects a lower-demand option, linking their
// action back to their original onboarding goal (Self-Determination Theory).

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';

class ValuesReminderCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDone;

  const ValuesReminderCard({
    super.key,
    required this.user,
    required this.onDone,
  });

  String get _goalContext {
    switch (user.goal) {
      case 'lose':
        return 'your goal of losing weight sustainably';
      case 'gain':
        return 'your goal of building strength';
      default:
        return 'your health and energy goals';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppColors.primaryAccent, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Plan Adjusted.',
            style: AppTextStyles.headingMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "You showed up today even when it was hard.\n\n"
            "This flexibility is exactly what protects $_goalContext over the long term. "
            "Rigid diets fail. Flexible systems last.",
            style: AppTextStyles.bodySecondary.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Got it',
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
