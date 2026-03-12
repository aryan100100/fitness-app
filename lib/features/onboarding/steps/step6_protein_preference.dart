// [HEALTH APP] — Onboarding Step 6: Protein Preference (NEW)
// Pre-selects 'moderate'. Always valid — Continue is always active.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step6ProteinPreference extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step6ProteinPreference(
      {super.key, required this.controller, required this.onNext});

  static const _options = [
    (
      icon: Icons.fitness_center_rounded,
      label: 'High Protein',
      description:
          'Ideal if you are lean, experienced in the gym, or prefer a high protein diet. Maximises muscle preservation.',
      value: 'high',
    ),
    (
      icon: Icons.check_circle_outline,
      label: 'Moderate — Recommended',
      description:
          'The science-backed sweet spot for most people. Enough to build and preserve muscle without overcomplicating your diet.',
      value: 'moderate',
    ),
    (
      icon: Icons.restaurant_outlined,
      label: 'Comfortable',
      description:
          'Still enough to build and preserve muscle, but more flexible. Good if you find it hard to hit high protein targets.',
      value: 'comfortable',
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
              Text('How much protein do you prefer?',
                  style: AppTextStyles.headingLarge),
              const SizedBox(height: 6),
              Text(
                'This helps us set your protein target. You can always adjust this later.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 28),

              ..._options.map((opt) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.cardSpacing),
                    child: _ProteinCard(
                      icon: opt.icon,
                      label: opt.label,
                      description: opt.description,
                      value: opt.value,
                      selected: controller.proteinPreference == opt.value,
                      onTap: () =>
                          controller.setProteinPreference(opt.value),
                    ),
                  )),

              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Continue',
                onTap: onNext, // always valid — moderate is pre-selected
              ),
              const SizedBox(height: 12),
              Text(
                "Not sure? Stick with Moderate — it works for most people and you can change this anytime in your profile.",
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondaryText),
                textAlign: TextAlign.center,
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
// Protein option card
// ---------------------------------------------------------------------------
class _ProteinCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _ProteinCard({
    required this.icon,
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
            Icon(icon, size: 26, color: AppColors.primaryAccent),
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
