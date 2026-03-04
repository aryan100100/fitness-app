// [HEALTH APP] — Onboarding Step 4: Body Composition (Optional)
// Feature 2: Sex-adjusted body fat range cards with skip option.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step4BodyFat extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step4BodyFat({super.key, required this.controller, required this.onNext});

  // ---------------------------------------------------------------------------
  // Range data — value is the key used in TDEECalculator._bodyFatModifiers
  // ---------------------------------------------------------------------------
  static const _maleLabelMap = {
    '3-5':   'Essential Fat',
    '6-10':  'Athlete',
    '11-13': 'Very Lean',
    '13-16': 'Lean',
    '16-20': 'Fit',
    '21-25': 'Average',
    '26-30': 'Above Average',
    '31-34': 'High',
    '35-39': 'Very High',
    '40+':   'Extremely High',
  };

  static const _femaleLabelMap = {
    '3-5':   'Essential Fat',
    '6-10':  'Elite Athlete',
    '11-13': 'Athlete',
    '13-16': 'Very Lean',
    '16-20': 'Lean',
    '21-25': 'Fit',
    '26-30': 'Average',
    '31-34': 'Above Average',
    '35-39': 'High',
    '40+':   'Very High',
  };

  static const _rangeLabels = <String>[
    '3-5', '6-10', '11-13', '13-16', '16-20',
    '21-25', '26-30', '31-34', '35-39', '40+',
  ];

  static const _displayRanges = <String>[
    '3–5%', '6–10%', '11–13%', '13–16%', '16–20%',
    '21–25%', '26–30%', '31–34%', '35–39%', '40%+',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final isMale = controller.biologicalSex == 'male';
        final labelMap = isMale ? _maleLabelMap : _femaleLabelMap;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.horizontalPadding, 40,
                  AppSpacing.horizontalPadding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Body Composition', style: AppTextStyles.headingLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Optional — select the range closest to you.\nThis fine-tunes your calorie estimate.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Scrollable range list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.horizontalPadding),
                itemCount: _rangeLabels.length,
                separatorBuilder: (ctx, i) =>
                    const SizedBox(height: AppSpacing.cardSpacing),
                itemBuilder: (ctx, i) {
                  final key = _rangeLabels[i];
                  final display = _displayRanges[i];
                  final label = labelMap[key] ?? '';
                  final selected = controller.bodyFatRange == key;

                  return _RangeCard(
                    display: display,
                    label: label,
                    selected: selected,
                    onTap: () => controller.setBodyFatRange(key),
                  );
                },
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.horizontalPadding, 20,
                  AppSpacing.horizontalPadding, 0),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Confirm Selection',
                    onTap: controller.bodyFatRange != null ? onNext : null,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      controller.skipBodyFat();
                      onNext();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Skip — I'm not sure",
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Body fat ranges are approximate. Even lab tests can be off by several percentage points.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual range card
// ---------------------------------------------------------------------------
class _RangeCard extends StatelessWidget {
  final String display;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeCard({
    required this.display,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryAccent.withValues(alpha: 0.1)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: selected ? AppColors.primaryAccent : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primaryAccent
                          : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.primaryAccent, size: 20),
          ],
        ),
      ),
    );
  }
}
