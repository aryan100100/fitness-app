// [HEALTH APP] — Low Motivation Option Card (Feature 8)
// Reusable card for the three choices in the Low Motivation flow.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class LowMotivationOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const LowMotivationOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary 
        ? AppColors.primaryAccent.withValues(alpha: 0.15)
        : (isDestructive ? AppColors.destructive.withValues(alpha: 0.1) : AppColors.cardSurface);
    
    final borderColor = isPrimary
        ? AppColors.primaryAccent.withValues(alpha: 0.4)
        : (isDestructive ? AppColors.destructive.withValues(alpha: 0.3) : AppColors.divider);

    final iconColor = isPrimary
        ? AppColors.primaryAccent
        : (isDestructive ? AppColors.destructive : AppColors.secondaryText);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.secondaryText.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
