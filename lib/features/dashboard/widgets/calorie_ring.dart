// [HEALTH APP] — Calorie Ring Widget
// 220px circular progress ring with 3-color state and 800ms animation.
// Built with CustomPaint — no fl_chart dependency needed for a single ring.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class CalorieRingWidget extends StatefulWidget {
  final double consumed;
  final double target;

  const CalorieRingWidget({
    super.key,
    required this.consumed,
    required this.target,
  });

  @override
  State<CalorieRingWidget> createState() => _CalorieRingWidgetState();
}

class _CalorieRingWidgetState extends State<CalorieRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CalorieRingWidget old) {
    super.didUpdateWidget(old);
    if (old.consumed != widget.consumed || old.target != widget.target) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _ringColor {
    final remaining = widget.target - widget.consumed;
    if (widget.consumed > widget.target) return AppColors.destructive;
    if (remaining <= 100) return AppColors.warning;
    return AppColors.primaryAccent;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.target - widget.consumed).round();
    final isOver = widget.consumed > widget.target;
    final overAmount = (widget.consumed - widget.target).round().abs();

    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, child) {
              final progress =
                  (widget.consumed / widget.target).clamp(0.0, 1.0) *
                      _progressAnim.value;
              return CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  ringColor: _ringColor,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOver ? '$overAmount' : '$remaining',
                        style: AppTextStyles.statsNumberLarge.copyWith(
                          fontSize: 40,
                          color: _ringColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOver ? 'kcal over' : 'kcal remaining',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Stat pills row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatPill(
              icon: '🍽️',
              label: 'Eaten',
              value: '${widget.consumed.round()} kcal',
            ),
            _StatPill(
              icon: '🎯',
              label: 'Goal',
              value: '${widget.target.round()} kcal',
            ),
            _EstimatePill(),
          ],
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;

  _RingPainter({required this.progress, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 14.0;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,           // Start at top
      2 * math.pi * progress,  // Sweep clockwise
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}

class _StatPill extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$icon ${label}', style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimatePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEstimateSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline,
                size: 13, color: AppColors.secondaryText),
            const SizedBox(width: 4),
            Text('±20% est.', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  void _showEstimateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text('About Calorie Estimates',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            Text(
              'Calorie logs are estimates. Research shows most people\'s logs are within 10–20% of their actual intake. That\'s completely normal and okay.\n\nWe refine your targets using your real weight trend over time — so the longer you use the app, the more accurate your personalised target becomes.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
