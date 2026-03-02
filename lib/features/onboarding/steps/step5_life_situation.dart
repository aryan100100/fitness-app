// [HEALTH APP] — Onboarding Step 5: Life Situation + Region

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step5LifeSituation extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onFinish;

  const Step5LifeSituation(
      {super.key, required this.controller, required this.onFinish});

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

              // --- Life situation cards ---
              Text('I am a...', style: AppTextStyles.caption),
              const SizedBox(height: 12),
              ...List.generate(_situations.length, (i) {
                final s = _situations[i];
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.cardSpacing),
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

              // --- Region dropdown ---
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
                label: 'See My Results 🎯',
                onTap: controller.step5Valid ? onFinish : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
