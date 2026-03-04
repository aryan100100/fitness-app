// [HEALTH APP] — Onboarding Step 7: Life Situation + Region (was Step 6)
// Renamed for 8-step onboarding. Class renamed to Step7LifeSituation.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step7LifeSituation extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step7LifeSituation(
      {super.key, required this.controller, required this.onNext});

  static const _situations = [
    (emoji: '🏠', title: 'Hostel Student', value: 'hostel_student'),
    (emoji: '💼', title: 'Office Worker', value: 'office_worker'),
    (emoji: '🖥️', title: 'Work From Home', value: 'work_from_home'),
    (emoji: '🍳', title: 'Homemaker', value: 'homemaker'),
    (emoji: '✨', title: 'Other', value: 'other'),
  ];

  static const _regions = [
    ('🇮🇳 India', 'India'),
    ('🇺🇸 USA', 'USA'),
    ('🇬🇧 UK', 'UK'),
    ('🌍 Other', 'Other'),
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
              Text('Your daily life', style: AppTextStyles.headingLarge),
              const SizedBox(height: 6),
              Text('This helps us suggest meals that actually fit your life.',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 28),

              Text('I am a...', style: AppTextStyles.caption),
              const SizedBox(height: 12),
              ...List.generate(_situations.length, (i) {
                final s = _situations[i];
                return Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppSpacing.cardSpacing),
                  child: AppCard(
                    isSelected: controller.lifeSituation == s.value,
                    onTap: () => controller.setLifeSituation(s.value),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(s.emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Text(s.title,
                            style: AppTextStyles.body.copyWith(
                                fontWeight:
                                    controller.lifeSituation == s.value
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                        const Spacer(),
                        if (controller.lifeSituation == s.value)
                          const Icon(Icons.check_circle,
                              color: AppColors.primaryAccent, size: 20),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),
              Text('Your region', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.region,
                    isExpanded: true,
                    dropdownColor: AppColors.elevatedCard,
                    iconEnabledColor: AppColors.primaryAccent,
                    style: AppTextStyles.body,
                    items: _regions
                        .map((r) => DropdownMenuItem(
                              value: r.$2,
                              child: Text(r.$1),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) controller.setRegion(v);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 36),
              PrimaryButton(
                label: 'Continue →',
                onTap: controller.step7Valid ? onNext : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
