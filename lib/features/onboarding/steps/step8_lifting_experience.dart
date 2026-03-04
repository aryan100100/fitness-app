// [HEALTH APP] — Onboarding Step 8: Lifting Experience (NEW, final step)
// No card pre-selected. Continue is disabled until user makes a choice.
// Does NOT affect any calculation — stored for future use by Person B's workout planner.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step8LiftingExperience extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onFinish;

  const Step8LiftingExperience(
      {super.key, required this.controller, required this.onFinish});

  static const _levels = [
    (
      emoji: '🌱',
      label: 'No Experience',
      description:
          'I have never followed a structured workout program before.',
      value: 'none',
    ),
    (
      emoji: '📈',
      label: 'Beginner',
      description:
          'I have trained on and off, or followed a program for less than 1 year consistently.',
      value: 'beginner',
    ),
    (
      emoji: '🏋️',
      label: 'Intermediate',
      description:
          'I have trained consistently for 1–3 years and understand the basics well.',
      value: 'intermediate',
    ),
    (
      emoji: '🏆',
      label: 'Advanced',
      description:
          'I have trained seriously for 3+ years with structured progressive programming.',
      value: 'advanced',
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
              Text("What's your training experience?",
                  style: AppTextStyles.headingLarge),
              const SizedBox(height: 6),
              Text(
                'This helps us personalise your workout recommendations later.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 28),

              ..._levels.map((lvl) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.cardSpacing),
                    child: _ExperienceCard(
                      emoji: lvl.emoji,
                      label: lvl.label,
                      description: lvl.description,
                      value: lvl.value,
                      selected: controller.liftingExperience == lvl.value,
                      onTap: () =>
                          controller.setLiftingExperience(lvl.value),
                    ),
                  )),

              PrimaryButton(
                label: "Continue →",
                onTap: controller.step8Valid ? onFinish : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Experience level card
// ---------------------------------------------------------------------------
class _ExperienceCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _ExperienceCard({
    required this.emoji,
    required this.label,
    required this.description,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryAccent.withValues(alpha: 0.08)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: selected
                ? AppColors.primaryAccent
                : const Color(0xFF2A2A2A),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primaryAccent
                          : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.primaryAccent, size: 20),
          ],
        ),
      ),
    );
  }
}
