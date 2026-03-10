// [HEALTH APP] — Adjustment Card (Feature 7)
// Generic wrapper card for all 5 situation cards on the dashboard.
// Dismissible with X button — dismissed state stored in memory (per session).

import 'package:flutter/material.dart';
import '../../../../core/constants/app_text_styles.dart';

class AdjustmentCard extends StatelessWidget {
  final Color borderColor;
  final String emoji;
  final String title;
  final String body;
  final List<Widget> actions;
  final VoidCallback onDismiss;
  final Widget? extraContent;

  const AdjustmentCard({
    super.key,
    required this.borderColor,
    required this.emoji,
    required this.title,
    required this.body,
    required this.actions,
    required this.onDismiss,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close,
                    color: Color(0xFF666666), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: AppTextStyles.caption
                  .copyWith(color: const Color(0xFFAAAAAA), height: 1.4)),
          if (extraContent != null) ...[
            const SizedBox(height: 12),
            extraContent!,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...actions,
          ],
          const SizedBox(height: 10),
          // Disclaimer
          const Text(
            "These suggestions are estimates based on your logged data, not medical advice. "
            "Targets are always kept within safe ranges. If you have a medical condition or history of disordered eating, please consult a professional.",
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact full-width tonal button for card actions
class CardActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const CardActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            )
          : TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF888888),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: onTap,
              child: Text(label,
                  style: const TextStyle(fontSize: 13)),
            ),
    );
  }
}
