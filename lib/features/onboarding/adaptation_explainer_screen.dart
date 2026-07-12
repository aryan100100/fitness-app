// [HEALTH APP] — Adaptation Explainer Screen
// Inserted between ResultsScreen and BottomNavShell.
// Animated loop diagram explaining NutriTrack's weekly adaptation mechanism.
// No back button — single forward path to BottomNavShell.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../widgets/primary_button.dart';
import '../nav_shell.dart';

class AdaptationExplainerScreen extends StatefulWidget {
  final UserModel user;
  const AdaptationExplainerScreen({super.key, required this.user});

  @override
  State<AdaptationExplainerScreen> createState() =>
      _AdaptationExplainerScreenState();
}

class _AdaptationExplainerScreenState extends State<AdaptationExplainerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arcAnim;
  late List<Animation<double>> _nodeAnims;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _arcAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // Each node fades in as the arc sweeps through its quadrant.
    _nodeAnims = List.generate(4, (i) {
      final start = i * 0.25;
      final end = (start + 0.25).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeIn),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Heading ───────────────────────────────────────────────────
              Text(
                'NutriTrack adapts to you',
                style: AppTextStyles.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your targets update every week based on your actual results — not a fixed formula.',
                style: AppTextStyles.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),

              // ── Animated loop diagram ─────────────────────────────────────
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _AdaptationLoopPainter(
                      animValue: _arcAnim.value,
                      nodeOpacities:
                          _nodeAnims.map((a) => a.value).toList(),
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),

              // ── CTA ───────────────────────────────────────────────────────
              PrimaryButton(
                label: 'Start Tracking →',
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (ctx) => BottomNavShell(user: widget.user),
                    ),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Node data
// ─────────────────────────────────────────────────────────────────────────────

class _NodeData {
  final String label;
  final IconData icon;
  const _NodeData(this.label, this.icon);
}

const List<_NodeData> _kNodes = [
  _NodeData('Log Food',        Icons.restaurant_outlined),
  _NodeData('Track Weight',    Icons.monitor_weight_outlined),
  _NodeData('Adapt Targets',   Icons.auto_graph),
  _NodeData('Stay Consistent', Icons.repeat),
];

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — arc + arrowhead + nodes
// ─────────────────────────────────────────────────────────────────────────────

class _AdaptationLoopPainter extends CustomPainter {
  final double animValue;
  final List<double> nodeOpacities;

  const _AdaptationLoopPainter({
    required this.animValue,
    required this.nodeOpacities,
  });

  static const double _loopRadius = 110.0;
  static const double _nodeRadius = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final sweepAngle = animValue * 2 * math.pi;

    // ── Arc ─────────────────────────────────────────────────────────────────
    if (sweepAngle > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: _loopRadius),
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = const Color(0xFFFF9F0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // ── Arrowhead at leading edge ────────────────────────────────────────
      _drawArrowhead(canvas, center, sweepAngle);
    }

    // ── Nodes ────────────────────────────────────────────────────────────────
    for (int i = 0; i < 4; i++) {
      final opacity = nodeOpacities[i].clamp(0.0, 1.0);
      if (opacity <= 0.0) continue;

      final angle = -math.pi / 2 + i * math.pi / 2;
      final nodeCenter = Offset(
        center.dx + _loopRadius * math.cos(angle),
        center.dy + _loopRadius * math.sin(angle),
      );
      _drawNode(canvas, nodeCenter, _kNodes[i], opacity);
    }
  }

  void _drawArrowhead(Canvas canvas, Offset center, double sweepAngle) {
    final leadAngle = -math.pi / 2 + sweepAngle;
    final tip = Offset(
      center.dx + _loopRadius * math.cos(leadAngle),
      center.dy + _loopRadius * math.sin(leadAngle),
    );

    // Tangent direction at leading edge (clockwise = leadAngle + π/2)
    final tangentAngle = leadAngle + math.pi / 2;
    final tx = math.cos(tangentAngle);
    final ty = math.sin(tangentAngle);
    // Inward normal
    final nx = -ty;
    final ny = tx;

    const arrowLen = 9.0;
    const arrowHalf = 4.5;

    final p1 = tip;
    final p2 = Offset(
      tip.dx - tx * arrowLen + nx * arrowHalf,
      tip.dy - ty * arrowLen + ny * arrowHalf,
    );
    final p3 = Offset(
      tip.dx - tx * arrowLen - nx * arrowHalf,
      tip.dy - ty * arrowLen - ny * arrowHalf,
    );

    canvas.drawPath(
      Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close(),
      Paint()..color = const Color(0xFFFF9F0A),
    );
  }

  void _drawNode(
      Canvas canvas, Offset center, _NodeData node, double opacity) {
    // Node fill
    canvas.drawCircle(
      center,
      _nodeRadius,
      Paint()
        ..color = const Color(0xFF1C1C1E).withValues(alpha: opacity),
    );
    // Node stroke
    canvas.drawCircle(
      center,
      _nodeRadius,
      Paint()
        ..color = const Color(0xFFFF9F0A).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Icon (drawn via TextPainter using Material Icons font)
    final iconPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(node.icon.codePoint),
        style: TextStyle(
          fontSize: 22,
          fontFamily: node.icon.fontFamily,
          package: node.icon.fontPackage,
          color: Colors.white.withValues(alpha: opacity),
        ),
      )
      ..layout();

    // Label (two-line max, 10px)
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )
      ..text = TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: opacity),
          height: 1.2,
        ),
      )
      ..layout(maxWidth: _nodeRadius * 2 - 6);

    // Layout: icon centred at (center.dy - labelH/2 - gap), label below
    const gap = 2.0;
    final totalH = iconPainter.height + gap + labelPainter.height;
    final iconY = center.dy - totalH / 2;
    final labelY = iconY + iconPainter.height + gap;

    iconPainter.paint(
      canvas,
      Offset(center.dx - iconPainter.width / 2, iconY),
    );
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, labelY),
    );
  }

  @override
  bool shouldRepaint(_AdaptationLoopPainter old) =>
      old.animValue != animValue ||
      !_listEq(old.nodeOpacities, nodeOpacities);

  static bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
