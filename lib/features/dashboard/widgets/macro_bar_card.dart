// [HEALTH APP] — Macro Bar Card
// Three equal-column primary macros + full-width fibre row.
// All bars animate from 0 → current over 600ms ease-in.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_card.dart';

class MacroBarCard extends StatefulWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final double targetFibre;

  const MacroBarCard({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.targetFibre,
  });

  @override
  State<MacroBarCard> createState() => _MacroBarCardState();
}

class _MacroBarCardState extends State<MacroBarCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(MacroBarCard old) {
    super.didUpdateWidget(old);
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Column(
            children: [
              // Row 1 — Three primary macros
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _MacroColumn(
                        label: 'Protein',
                        value: widget.protein,
                        target: widget.targetProtein,
                        barColor: AppColors.proteinBar,
                        animProgress: _anim.value,
                      ),
                    ),
                    VerticalDivider(
                        color: AppColors.divider, width: 1, thickness: 1),
                    Expanded(
                      child: _MacroColumn(
                        label: 'Carbs',
                        value: widget.carbs,
                        target: widget.targetCarbs,
                        barColor: AppColors.carbBar,
                        animProgress: _anim.value,
                      ),
                    ),
                    VerticalDivider(
                        color: AppColors.divider, width: 1, thickness: 1),
                    Expanded(
                      child: _MacroColumn(
                        label: 'Fat',
                        value: widget.fat,
                        target: widget.targetFat,
                        barColor: AppColors.fatBar,
                        animProgress: _anim.value,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: AppColors.divider, height: 24, thickness: 1),

              // Row 2 — Fibre
              _FibreRow(
                value: widget.fibre,
                target: widget.targetFibre,
                animProgress: _anim.value,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single macro column
// ---------------------------------------------------------------------------
class _MacroColumn extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color barColor;
  final double animProgress;

  const _MacroColumn({
    required this.label,
    required this.value,
    required this.target,
    required this.barColor,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isExceeded = value > target && target > 0;
    final progress =
        target > 0 ? (value / target).clamp(0.0, 1.0) * animProgress : 0.0;
    final activeColor = isExceeded ? AppColors.destructive : barColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${value.round()}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isExceeded
                        ? AppColors.destructive
                        : AppColors.primaryText,
                  ),
                ),
                TextSpan(
                  text: 'g',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            '/ ${target.round()}g',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fibre row
// ---------------------------------------------------------------------------
class _FibreRow extends StatelessWidget {
  final double value;
  final double target;
  final double animProgress;

  const _FibreRow({
    required this.value,
    required this.target,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    const fibreColor = Color(0xFFB39DDB); // soft purple
    final progress =
        target > 0 ? (value / target).clamp(0.0, 1.0) * animProgress : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showFibreTooltip(context),
              child: Row(
                children: [
                  Text('Fibre',
                      style: AppTextStyles.caption.copyWith(
                          color: fibreColor)),
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 13, color: fibreColor),
                ],
              ),
            ),
            Text(
              '${value.round()}g / ${target.round()}g',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation<Color>(fibreColor),
          ),
        ),
      ],
    );
  }

  void _showFibreTooltip(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why Fibre Matters',
                style:
                    AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'Fibre helps you feel full and supports gut health. Most people don\'t eat enough. Aim for your daily target for better satiety and long-term health.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
