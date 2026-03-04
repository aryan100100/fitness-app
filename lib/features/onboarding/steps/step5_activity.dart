// [HEALTH APP] — Onboarding Step 5: Activity Level (was Step 4)
// Renamed for Feature 2's 6-step onboarding.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step5Activity extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step5Activity(
      {super.key, required this.controller, required this.onNext});

  static const _levels = [
    (
      emoji: '🪑',
      title: 'Sedentary',
      subtitle: 'Desk job, little to no exercise',
      value: 'sedentary',
    ),
    (
      emoji: '🚶',
      title: 'Lightly Active',
      subtitle: 'Light exercise 1–3 days/week',
      value: 'lightly_active',
    ),
    (
      emoji: '🏃',
      title: 'Moderately Active',
      subtitle: 'Exercise 3–5 days/week',
      value: 'moderately_active',
    ),
    (
      emoji: '🔥',
      title: 'Very Active',
      subtitle: 'Hard training 6–7 days/week or physical job',
      value: 'very_active',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('How active are you?', style: AppTextStyles.headingLarge),
              const SizedBox(height: 6),
              Text('Be honest — this shapes your calorie target.',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 32),

              ..._levels.map((level) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.cardSpacing),
                    child: AppCard(
                      isSelected: controller.activityLevel == level.value,
                      onTap: () => controller.setActivityLevel(level.value),
                      child: Row(
                        children: [
                          Text(level.emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(level.title,
                                    style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(level.subtitle,
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          if (controller.activityLevel == level.value)
                            const Icon(Icons.check_circle,
                                color: AppColors.primaryAccent, size: 22),
                        ],
                      ),
                    ),
                  )),

              PrimaryButton(
                label: 'Continue',
                onTap: controller.step5Valid ? onNext : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
