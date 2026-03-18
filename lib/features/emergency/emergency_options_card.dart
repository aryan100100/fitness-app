// [HEALTH APP] — Emergency Options Cards (Feature 6)
// The two selectable recovery option cards shown inside EmergencyButtonSheet.
// Option A: Adjust This Week (redistribute). Option B: Extend My Timeline.

import 'package:flutter/material.dart';
import '../../../core/services/emergency_service.dart';

class EmergencyOptionsCard extends StatelessWidget {
  final bool optionAEnabled;
  final String? optionABlockReason;
  final RedistributionPlan? planA;
  final int extraDaysB;
  final String newGoalDateLabel;
  final bool recommendB;
  final String? selectedOption; // 'A' | 'B' | null
  final ValueChanged<String> onOptionSelected;
  final double standardDailyTarget;

  const EmergencyOptionsCard({
    super.key,
    required this.optionAEnabled,
    this.optionABlockReason,
    this.planA,
    required this.extraDaysB,
    required this.newGoalDateLabel,
    this.recommendB = false,
    required this.selectedOption,
    required this.onOptionSelected,
    required this.standardDailyTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your path forward:',
          style: const TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // ── Option A ────────────────────────────────────────────────────────
        _OptionCard(
          isSelected: selectedOption == 'A',
          isEnabled: optionAEnabled,
          onTap: optionAEnabled ? () => onOptionSelected('A') : null,
          icon: '📅',
          title: 'Adjust This Week',
          description: planA?.spillsToNextWeek == true
              ? 'Spread the extra calories across the next ${planA!.daysAffected} days (extending into next week). Your daily target will be slightly lower during this period.'
              : 'Spread the extra calories across the remaining days this week. Your daily target will be slightly lower for a short period.',
          previewWidget: planA != null
              ? _PlanAPreview(plan: planA!, standardTarget: standardDailyTarget)
              : null,
          blockedMessage: optionABlockReason,
        ),

        const SizedBox(height: 12),

        // ── Option B ────────────────────────────────────────────────────────
        _OptionCard(
          isSelected: selectedOption == 'B',
          isEnabled: true,
          onTap: () => onOptionSelected('B'),
          icon: '🗓️',
          title: 'Extend My Timeline',
          badge: recommendB ? 'Recommended' : null,
          description:
              'Keep your daily targets exactly as they are and add a small number of days to your goal timeline instead.',
          previewWidget: _PlanBPreview(
            extraDays: extraDaysB,
            newGoalDateLabel: newGoalDateLabel,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single option card
// ---------------------------------------------------------------------------
class _OptionCard extends StatelessWidget {
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;
  final String icon;
  final String title;
  final String? badge;
  final String description;
  final Widget? previewWidget;
  final String? blockedMessage;

  const _OptionCard({
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
    required this.icon,
    required this.title,
    this.badge,
    required this.description,
    this.previewWidget,
    this.blockedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final amber = const Color(0xFFFFB300);
    final borderColor = isSelected
        ? amber
        : isEnabled
            ? const Color(0xFF3A3A3A)
            : const Color(0xFF2A2A2A);
    final bgColor = isSelected
        ? amber.withValues(alpha: 0.08)
        : isEnabled
            ? const Color(0xFF1E1E1E)
            : const Color(0xFF181818);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isEnabled
                          ? const Color(0xFFE0E0E0)
                          : const Color(0xFF555555),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: amber.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.black, size: 14),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              description,
              style: TextStyle(
                color: isEnabled
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF444444),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            // Preview numbers
            if (previewWidget != null && isEnabled) ...[
              const SizedBox(height: 12),
              previewWidget!,
            ],

            // Blocked reason
            if (blockedMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline,
                        color: Color(0xFF666666), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        blockedMessage!,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Option A preview numbers
// ---------------------------------------------------------------------------
class _PlanAPreview extends StatelessWidget {
  final RedistributionPlan plan;
  final double standardTarget;

  const _PlanAPreview({required this.plan, required this.standardTarget});

  @override
  Widget build(BuildContext context) {
    final amber = const Color(0xFFFFB300);
    final backLabel = EmergencyService.backToNormalLabel(plan.backToNormalOn);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _PreviewRow(
            label: 'New daily target for next ${plan.daysAffected} ${plan.daysAffected == 1 ? 'day' : 'days'}',
            value: '${plan.newDailyTarget.round()} kcal',
            valueColor: amber,
          ),
          const SizedBox(height: 6),
          _PreviewRow(
            label: 'That\'s less than usual per day',
            value: '${plan.dailyReduction.round()} kcal',
            valueColor: amber,
          ),
          const SizedBox(height: 6),
          _PreviewRow(
            label: 'Back to normal on',
            value: backLabel,
            valueColor: const Color(0xFFE0E0E0),
          ),
          if (plan.spillsToNextWeek) ...[
            const SizedBox(height: 6),
            const Text(
              '2-week spread — your overage is higher than we can safely fit into this week alone.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Option B preview numbers
// ---------------------------------------------------------------------------
class _PlanBPreview extends StatelessWidget {
  final int extraDays;
  final String newGoalDateLabel;

  const _PlanBPreview(
      {required this.extraDays, required this.newGoalDateLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _PreviewRow(
            label: 'New estimated goal date',
            value: newGoalDateLabel,
            valueColor: const Color(0xFFFFB300),
          ),
          const SizedBox(height: 6),
          _PreviewRow(
            label: 'That\'s later than before',
            value: '$extraDays ${extraDays == 1 ? 'day' : 'days'}',
            valueColor: const Color(0xFFFFB300),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on a 7,700 kcal/kg estimate — actual results vary slightly.',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _PreviewRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
