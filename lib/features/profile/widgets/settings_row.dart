// [HEALTH APP] — Profile: Reusable Tappable Settings Row
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String? trailing;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;
  final bool isLast;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lColor = labelColor ?? AppColors.primaryText;
    final iColor = iconColor ?? AppColors.secondaryText;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isLast ? const Radius.circular(16) : Radius.zero,
            ),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: iColor, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: AppTextStyles.body.copyWith(color: lColor)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!,
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.secondaryText,
                                  fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    Text(trailing!,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryAccent,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                  ],
                  if (showChevron)
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.secondaryText, size: 18),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, indent: 50, color: AppColors.divider),
      ],
    );
  }
}
