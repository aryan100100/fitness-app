// [HEALTH APP] — Onboarding Step 6: Life Situation + Region (was Step 5)
// Renamed for Feature 2's 6-step onboarding.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step6LifeSituation extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onFinish;

  const Step6LifeSituation(
      {super.key, required this.controller, required this.onFinish});

  static const _situations = [
    (icon: Icons.home_work_outlined, title: 'Hostel Student', value: 'hostel_student'),
    (icon: Icons.work_outline_rounded, title: 'Office Worker', value: 'office_worker'),
    (icon: Icons.computer_rounded, title: 'Work From Home', value: 'work_from_home'),
    (icon: Icons.restaurant_outlined, title: 'Homemaker', value: 'homemaker'),
    (icon: Icons.auto_awesome_rounded, title: 'Other', value: 'other'),
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
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.cardSpacing),
                  child: AppCard(
                    isSelected: controller.lifeSituation == s.value,
                    onTap: () => controller.setLifeSituation(s.value),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(s.icon, size: 26, color: AppColors.primaryAccent),
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
                onTap: controller.step6Valid ? onFinish : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
