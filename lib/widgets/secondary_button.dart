// [HEALTH APP] — Reusable Secondary Button (outline style)

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: AppSpacing.buttonHeight,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: Border.all(color: AppColors.primaryAccent, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.buttonLabel.copyWith(
            color: AppColors.primaryAccent,
          ),
        ),
      ),
    );
  }
}
