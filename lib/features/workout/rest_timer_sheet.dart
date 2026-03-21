// [HEALTH APP] — Rest Timer Bottom Sheet
// Hevy-style animated countdown. Triggers after a set is checked off.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class RestTimerSheet extends StatefulWidget {
  final int initialSeconds;
  final String? nextSetLabel;

  const RestTimerSheet({
    super.key,
    this.initialSeconds = 90,
    this.nextSetLabel,
  });

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet>
    with SingleTickerProviderStateMixin {
  late int _remaining;
  late int _total;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialSeconds;
    _total = widget.initialSeconds;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 0) {
        t.cancel();
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() => _remaining--);
    });
  }

  void _adjust(int delta) {
    setState(() {
      _remaining = (_remaining + delta).clamp(5, 600);
      _total = math.max(_total, _remaining);
    });
  }

  String get _label {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress => _remaining / _total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Text('Rest', style: AppTextStyles.body.copyWith(
            fontSize: 13,
            color: AppColors.secondaryText,
            letterSpacing: 1.2,
          )),
          const SizedBox(height: 20),

          // Animated ring + timer
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _RingPainter(
                    progress: _progress,
                    color: AppColors.primaryAccent,
                  ),
                ),
                // Timer text
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, _) {
                    final opacity = _remaining <= 5
                        ? 0.5 + 0.5 * _pulseController.value
                        : 1.0;
                    return Opacity(
                      opacity: opacity,
                      child: Text(
                        _label,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                          color: _remaining <= 10
                              ? AppColors.destructive
                              : AppColors.primaryText,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (widget.nextSetLabel != null) ...[
            Text(
              'Next: ${widget.nextSetLabel}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 20),

          // Adjust buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AdjustButton(label: '−15s', onTap: () => _adjust(-15)),
              const SizedBox(width: 16),
              _AdjustButton(label: '+15s', onTap: () => _adjust(15)),
            ],
          ),
          const SizedBox(height: 20),

          // Skip
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Skip Rest',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ring painter
// ---------------------------------------------------------------------------
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 10;
    const strokeWidth = 7.0;

    // Background track
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = AppColors.divider
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.elevatedCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(label,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
