// [HEALTH APP] — Goal Progress Card (Feature 7, Situation 2)
// Shows when goal date is within 7 days.
// Three selectable options: extend date, adjust goal weight, keep as planned.
// Never suggests accelerating weight loss.

import 'package:flutter/material.dart';
import '../../../../core/services/auto_adjustment_service.dart';
import 'adjustment_card.dart';

class GoalProgressCard extends StatefulWidget {
  final GoalProgressSummary progress;
  final VoidCallback onDismiss;
  final Future<void> Function(String option) onApply;

  const GoalProgressCard({
    super.key,
    required this.progress,
    required this.onDismiss,
    required this.onApply,
  });

  @override
  State<GoalProgressCard> createState() => _GoalProgressCardState();
}

class _GoalProgressCardState extends State<GoalProgressCard> {
  String? _selected; // 'extend_date' | 'adjust_goal' | 'keep_going'
  bool _applying = false;

  static const _amber = Color(0xFFFFB300);
  static const _green = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final borderColor = p.isAheadOfPace ? _green : _amber;

    return AdjustmentCard(
      borderColor: borderColor,
      emoji: '🏁',
      title: 'Your goal date is in ${p.daysRemaining} ${p.daysRemaining == 1 ? 'day' : 'days'}',
      body: '',
      onDismiss: widget.onDismiss,
      extraContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress summary
          _ProgressSummary(progress: p, accentColor: borderColor),
          const SizedBox(height: 16),

          // Options
          _OptionTile(
            id: 'extend_date',
            selected: _selected,
            icon: '📅',
            title: 'Extend my timeline',
            subtitle: 'Keep my current pace. Adjust my goal date to match.',
            detail: 'New estimated date: ${p.suggestedNewGoalDate}',
            onTap: (id) => setState(() => _selected = id),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            id: 'adjust_goal',
            selected: _selected,
            icon: '🎯',
            title: 'Adjust my goal amount',
            subtitle: 'Change my target weight to what I can realistically reach at my current pace.',
            detail: 'Suggested target: ${p.suggestedNewTargetWeight.toStringAsFixed(1)} kg',
            onTap: (id) => setState(() => _selected = id),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            id: 'keep_going',
            selected: _selected,
            icon: '🌱',
            title: 'Keep going as planned',
            subtitle: "I'll accept I might not fully reach my original goal by this date — and that's okay. Progress at any pace is real progress.",
            detail: null,
            onTap: (id) => setState(() => _selected = id),
          ),

          if (_selected != null) ...[
            const SizedBox(height: 14),
            CardActionButton(
              label: _applying ? 'Applying…' : 'Confirm choice',
              onTap: _applying
                  ? () {}
                  : () async {
                      setState(() => _applying = true);
                      try {
                        await widget.onApply(_selected!);
                        widget.onDismiss();
                      } catch (_) {
                        if (mounted) setState(() => _applying = false);
                      }
                    },
            ),
          ],
        ],
      ),
      actions: const [],
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  final GoalProgressSummary progress;
  final Color accentColor;

  const _ProgressSummary(
      {required this.progress, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow('Starting weight', '${p.startingWeight.toStringAsFixed(1)} kg'),
        const SizedBox(height: 4),
        _StatRow('Current weight (7-day avg)', '${p.currentAvg.toStringAsFixed(1)} kg'),
        const SizedBox(height: 4),
        _StatRow(
          'Change so far',
          '${p.changeKg > 0 ? '-' : '+'}${p.changeKg.abs().toStringAsFixed(1)} kg of ${p.totalGoalKg.toStringAsFixed(1)} kg goal',
          valueColor: accentColor,
        ),
        const SizedBox(height: 10),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.progressPercent,
            backgroundColor: const Color(0xFF2A2A2A),
            color: accentColor,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(p.progressPercent * 100).round()}% of goal',
          style: TextStyle(
              color: accentColor, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? const Color(0xFFE0E0E0),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String id;
  final String? selected;
  final String icon;
  final String title;
  final String subtitle;
  final String? detail;
  final ValueChanged<String> onTap;

  const _OptionTile({
    required this.id,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == id;
    final amber = const Color(0xFFFFB300);
    return GestureDetector(
      onTap: () => onTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? amber.withOpacity(0.08) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? amber : const Color(0xFF3A3A3A),
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: const Color(0xFFE0E0E0),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          height: 1.4)),
                  if (detail != null && isSelected) ...[
                    const SizedBox(height: 5),
                    Text(detail!,
                        style: TextStyle(
                            color: amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 18,
                height: 18,
                decoration:
                    BoxDecoration(color: amber, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.black, size: 12),
              ),
          ],
        ),
      ),
    );
  }
}
