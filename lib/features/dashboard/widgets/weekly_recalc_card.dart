// [HEALTH APP] — Weekly Recalc Card (Feature 7)
// Shows the outcome of the weekly check-in recalculation (Situation 4).
// Different content based on RecalcOutcome.

import 'package:flutter/material.dart';
import '../../../../core/services/auto_adjustment_service.dart';
import 'adjustment_card.dart';

class WeeklyRecalcCard extends StatelessWidget {
  final WeeklyRecalcResult result;
  final VoidCallback onDismiss;
  final Future<void> Function()? onApply;   // null for info-only outcomes
  final VoidCallback? onSkip;

  const WeeklyRecalcCard({
    super.key,
    required this.result,
    required this.onDismiss,
    this.onApply,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB300);

    return switch (result.outcome) {
      RecalcOutcome.insufficientData ||
      RecalcOutcome.stable ||
      RecalcOutcome.menstrualSkip =>
        _InfoCard(result: result, onDismiss: onDismiss),

      RecalcOutcome.rapidLoss => AdjustmentCard(
          borderColor: amber,
          emoji: '⚠️',
          title: 'A note before updating your targets',
          body: result.message,
          onDismiss: onDismiss,
          actions: [
            CardActionButton(
              label: 'My logs seem accurate — apply update',
              onTap: () => onApply?.call(),
            ),
            const SizedBox(height: 6),
            CardActionButton(
              label: 'Skip this week',
              onTap: () {
                onSkip?.call();
                onDismiss();
              },
              isPrimary: false,
            ),
          ],
        ),

      RecalcOutcome.mediumChange => _ChangeCard(
          result: result,
          borderColor: amber,
          onApply: onApply,
          onSkip: onSkip,
          onDismiss: onDismiss,
        ),

      RecalcOutcome.largeChange => _ChangeCard(
          result: result,
          borderColor: amber,
          onApply: onApply,
          onSkip: onSkip,
          onDismiss: onDismiss,
          isPhased: true,
        ),

      RecalcOutcome.smallChange => _SmallChangeBanner(
          message: result.message,
          onDismiss: onDismiss,
        ),
    };
  }
}

/// Info-only card for insufficient/stable/menstrual skip
class _InfoCard extends StatelessWidget {
  final WeeklyRecalcResult result;
  final VoidCallback onDismiss;

  const _InfoCard({required this.result, required this.onDismiss});

  String get _emoji => switch (result.outcome) {
        RecalcOutcome.stable => '⚖️',
        RecalcOutcome.menstrualSkip => '💛',
        _ => '📊',
      };

  String get _title => switch (result.outcome) {
        RecalcOutcome.stable => 'Weight stable this week',
        RecalcOutcome.menstrualSkip => 'Weekly update paused',
        _ => 'A few more weigh-ins needed',
      };

  @override
  Widget build(BuildContext context) {
    return AdjustmentCard(
      borderColor: const Color(0xFF3A3A3A),
      emoji: _emoji,
      title: _title,
      body: result.message,
      onDismiss: onDismiss,
      actions: [
        CardActionButton(
          label: 'Got it',
          onTap: onDismiss,
          isPrimary: false,
        ),
      ],
    );
  }
}

/// Medium or large change card with before/after numbers
class _ChangeCard extends StatefulWidget {
  final WeeklyRecalcResult result;
  final Color borderColor;
  final Future<void> Function()? onApply;
  final VoidCallback? onSkip;
  final VoidCallback onDismiss;
  final bool isPhased;

  const _ChangeCard({
    required this.result,
    required this.borderColor,
    required this.onApply,
    required this.onSkip,
    required this.onDismiss,
    this.isPhased = false,
  });

  @override
  State<_ChangeCard> createState() => _ChangeCardState();
}

class _ChangeCardState extends State<_ChangeCard> {
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.result.details!;
    const amber = Color(0xFFFFB300);

    return AdjustmentCard(
      borderColor: amber,
      emoji: widget.isPhased ? '📈' : '🔄',
      title: widget.isPhased
          ? 'Gradual target update'
          : 'Your weekly targets can be updated',
      body: widget.result.message,
      onDismiss: widget.onDismiss,
      extraContent: _BeforeAfterTable(details: d, isPhased: widget.isPhased),
      actions: [
        CardActionButton(
          label: _applying ? 'Applying…' : 'Apply update',
          onTap: _applying
              ? () {}
              : () async {
                  setState(() => _applying = true);
                  try {
                    await widget.onApply?.call();
                    widget.onDismiss();
                  } catch (_) {
                    if (mounted) setState(() => _applying = false);
                  }
                },
        ),
        const SizedBox(height: 6),
        CardActionButton(
          label: 'Keep current targets',
          onTap: () {
            widget.onSkip?.call();
            widget.onDismiss();
          },
          isPrimary: false,
        ),
      ],
    );
  }
}

class _BeforeAfterTable extends StatelessWidget {
  final RecalcDetails details;
  final bool isPhased;

  const _BeforeAfterTable({required this.details, required this.isPhased});

  @override
  Widget build(BuildContext context) {
    final amber = const Color(0xFFFFB300);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _Row(
            label: 'Daily target',
            before: '${details.oldTargetCalories.round()} kcal',
            after: isPhased
                ? '${details.newTargetCalories.round()} kcal (step 1 of 2)'
                : '${details.newTargetCalories.round()} kcal',
            accent: amber,
          ),
          const SizedBox(height: 6),
          _Row(
            label: 'Based on weight',
            before: '${details.previousWeeklyAvg.toStringAsFixed(1)} kg avg',
            after: '${details.currentWeeklyAvg.toStringAsFixed(1)} kg avg',
            accent: amber,
          ),
          if (isPhased) ...[
            const SizedBox(height: 8),
            Text(
              'The remaining ${details.phasedAdjustment.round()} kcal will be applied next week.',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String before;
  final String after;
  final Color accent;

  const _Row(
      {required this.label,
      required this.before,
      required this.after,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ),
        Text(before,
            style: const TextStyle(
                color: Color(0xFF666666), fontSize: 11,
                decoration: TextDecoration.lineThrough)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFF666666)),
        ),
        Text(after,
            style: TextStyle(
                color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Slim green banner for small (silent) changes
class _SmallChangeBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _SmallChangeBanner(
      {required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A27),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Color(0xFF81C784), fontSize: 13)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 15, color: Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }
}
