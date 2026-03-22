// [HEALTH APP] — Emergency Button Sheet (Feature 6)
// DraggableScrollableSheet at 85% screen height.
// Page 1: opening info, safety-checked options, disclaimer.
// Page 2: Gemini message + summary card after user confirms.
// Never full-screen. Amber, never red. No banned words.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/emergency_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../models/dashboard_summary.dart';
import '../../../models/user_model.dart';
import 'emergency_options_card.dart';

class EmergencyButtonSheet extends StatefulWidget {
  final UserModel user;
  final DashboardSummary summary;

  const EmergencyButtonSheet({
    super.key,
    required this.user,
    required this.summary,
  });

  @override
  State<EmergencyButtonSheet> createState() => _EmergencyButtonSheetState();
}

class _EmergencyButtonSheetState extends State<EmergencyButtonSheet> {
  static const _bg = Color(0xFF1A1A1A);

  // Page state
  bool _loadingOptions = true;
  EmergencyOptions? _options;
  String? _selectedOption; // 'A' | 'B' | null
  bool _isApplying = false;

  // Page 2 state
  bool _showConfirmation = false;
  bool _loadingGemini = false;
  String? _geminiMessage;
  String? _summaryLine1;
  String? _summaryLine2;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final daysRemaining = EmergencyService.daysRemainingInWeek();
    final overage = (widget.summary.totalCalories - widget.summary.targetCalories)
        .clamp(0, double.infinity)
        .toDouble();

    final options = await EmergencyService.instance.getAvailableOptions(
      user: widget.user,
      overageKcal: overage,
      daysRemainingInWeek: daysRemaining,
    );

    if (mounted) {
      setState(() {
        _options = options;
        _loadingOptions = false;
      });
    }
  }

  double get _overage =>
      (widget.summary.totalCalories - widget.summary.targetCalories)
          .clamp(0, double.infinity)
          .toDouble();

  int get _daysRemaining => EmergencyService.daysRemainingInWeek();

  Future<void> _onApply() async {
    if (_selectedOption == null || _isApplying) return;
    setState(() => _isApplying = true);

    HapticFeedback.mediumImpact();

    try {
      final userId = widget.user.id ?? '';
      final options = _options!;

      if (_selectedOption == 'A' && options.planA != null) {
        await EmergencyService.instance.applyRedistribution(
          userId: userId,
          plan: options.planA!,
        );
        await EmergencyService.instance.logUsage(
          userId: userId,
          overageKcal: _overage,
          optionChosen: 'redistribute',
        );
        final plan = options.planA!;
        _summaryLine1 =
            'For the next ${plan.daysAffected} ${plan.daysAffected == 1 ? 'day' : 'days'}, your target is ${plan.newDailyTarget.round()} kcal/day.';
        _summaryLine2 =
            'Back to your usual target on ${EmergencyService.backToNormalLabel(plan.backToNormalOn)}.';
      } else {
        await EmergencyService.instance.applyDateExtension(
          userId: userId,
          extraDays: options.extraDaysB,
          currentGoalEndDate: widget.user.goalEndDate,
        );
        await EmergencyService.instance.logUsage(
          userId: userId,
          overageKcal: _overage,
          optionChosen: 'extend_date',
        );
        _summaryLine1 = 'Your daily targets stay exactly the same.';
        _summaryLine2 = 'New goal date: ${options.newGoalDateLabel}.';
      }

      // Fetch Gemini message
      setState(() {
        _isApplying = false;
        _showConfirmation = true;
        _loadingGemini = true;
      });

      final adjustmentType = _selectedOption == 'A' ? 'distribute_week' : 'extend_date';
      final message = await GeminiService.instance.generateEmergencyMessage(
        caloriesOver: _overage.round(),
        adjustmentType: adjustmentType,
      );

      if (mounted) {
        setState(() {
          _geminiMessage = message ?? _fallbackMessage(adjustmentType);
          _loadingGemini = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
    }
  }

  String _fallbackMessage(String type) {
    if (type == 'distribute_week') {
      return "One high-calorie day is a completely normal part of any long-term journey. "
          "Your plan has been smoothly adjusted so you can move forward with confidence. "
          "Tomorrow, aim for a nourishing, balanced day — you've got this.";
    }
    return "Taking a flexible approach shows real self-awareness. "
        "Your goal date has been shifted slightly, and your daily rhythm stays exactly the same. "
        "Tomorrow is a fresh opportunity to keep building your healthy habits.";
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              _DragHandle(),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: _showConfirmation
                      ? _ConfirmationPage(
                          geminiMessage: _geminiMessage,
                          loadingGemini: _loadingGemini,
                          summaryLine1: _summaryLine1 ?? '',
                          summaryLine2: _summaryLine2 ?? '',
                          onDone: () => Navigator.of(context).pop(true),
                        )
                      : _OptionsPage(
                          loadingOptions: _loadingOptions,
                          options: _options,
                          summary: widget.summary,
                          user: widget.user,
                          selectedOption: _selectedOption,
                          isApplying: _isApplying,
                          daysRemaining: _daysRemaining,
                          overage: _overage,
                          onOptionSelected: (opt) =>
                              setState(() => _selectedOption = opt),
                          onApply: _onApply,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — Info + Options
// ---------------------------------------------------------------------------
class _OptionsPage extends StatelessWidget {
  final bool loadingOptions;
  final EmergencyOptions? options;
  final DashboardSummary summary;
  final UserModel user;
  final String? selectedOption;
  final bool isApplying;
  final int daysRemaining;
  final double overage;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onApply;

  const _OptionsPage({
    required this.loadingOptions,
    required this.options,
    required this.summary,
    required this.user,
    required this.selectedOption,
    required this.isApplying,
    required this.daysRemaining,
    required this.overage,
    required this.onOptionSelected,
    required this.onApply,
  });

  static const _amber = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amber glow header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _amber.withValues(alpha: 0.12),
                const Color(0xFF1A1A1A),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "It's okay.",
                style: TextStyle(
                  color: Color(0xFFE8E8E8),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "One high-calorie day is completely normal. Let's look at your options.",
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Most of today's extra calories are stored as glycogen and water — not fat. "
                  "Your long-term progress depends on your weekly pattern, not a single day.",
                  style: TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Situation numbers
        _SituationCard(
          targetCalories: summary.targetCalories,
          loggedCalories: summary.totalCalories,
          overage: overage,
          daysRemaining: daysRemaining,
        ),

        const SizedBox(height: 20),

        // Divider
        Container(
          height: 1,
          color: const Color(0xFF2A2A2A),
        ),

        const SizedBox(height: 20),

        // Intervention banner (if applicable)
        if (options != null &&
            options!.interventionLevel != InterventionLevel.none)
          _InterventionBanner(
            level: options!.interventionLevel,
            message: options!.interventionMessage ?? '',
          ),

        if (options != null &&
            options!.interventionLevel != InterventionLevel.none)
          const SizedBox(height: 16),

        // Options
        if (loadingOptions)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(
                color: _amber,
                strokeWidth: 2,
              ),
            ),
          )
        else if (options != null)
          EmergencyOptionsCard(
            optionAEnabled: options!.optionAEnabled,
            optionABlockReason: options!.optionABlockReason,
            planA: options!.planA,
            extraDaysB: options!.extraDaysB,
            newGoalDateLabel: options!.newGoalDateLabel,
            recommendB: options!.recommendB,
            selectedOption: selectedOption,
            onOptionSelected: onOptionSelected,
            standardDailyTarget: summary.targetCalories,
          ),

        const SizedBox(height: 24),

        // Apply button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedOption != null ? _amber : const Color(0xFF2A2A2A),
              foregroundColor:
                  selectedOption != null ? Colors.black : const Color(0xFF555555),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: selectedOption != null && !isApplying ? onApply : null,
            child: isApplying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Apply This Adjustment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Disclaimer
        const _Disclaimer(),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Situation numbers card
// ---------------------------------------------------------------------------
class _SituationCard extends StatelessWidget {
  final double targetCalories;
  final double loggedCalories;
  final double overage;
  final int daysRemaining;

  const _SituationCard({
    required this.targetCalories,
    required this.loggedCalories,
    required this.overage,
    required this.daysRemaining,
  });

  static const _amber = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          _StatRow(label: "Today's target", value: '${targetCalories.round()} kcal'),
          const SizedBox(height: 8),
          _StatRow(label: "Today's logged intake", value: '${loggedCalories.round()} kcal'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF2A2A2A), height: 1),
          ),
          _StatRow(
            label: "Today's overage",
            value: '+${overage.round()} kcal',
            valueColor: _amber,
            bold: true,
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Days remaining this week',
            value: '$daysRemaining',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFFE0E0E0),
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Intervention banner
// ---------------------------------------------------------------------------
class _InterventionBanner extends StatelessWidget {
  final InterventionLevel level;
  final String message;

  const _InterventionBanner({required this.level, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFFFFB300), size: 16),
              const SizedBox(width: 8),
              Text(
                level == InterventionLevel.strong
                    ? 'A note on your journey'
                    : 'A gentle observation',
                style: const TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (level == InterventionLevel.strong ||
              level == InterventionLevel.mild) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB300),
                      side: const BorderSide(color: Color(0xFFFFB300)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Future: nav to goal pace screen
                      Navigator.of(context).pop();
                    },
                    child: const Text('Review my targets',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Keep my current plan',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — Confirmation
// ---------------------------------------------------------------------------
class _ConfirmationPage extends StatelessWidget {
  final String? geminiMessage;
  final bool loadingGemini;
  final String summaryLine1;
  final String summaryLine2;
  final VoidCallback onDone;

  const _ConfirmationPage({
    required this.geminiMessage,
    required this.loadingGemini,
    required this.summaryLine1,
    required this.summaryLine2,
    required this.onDone,
  });

  static const _amber = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Success header
        const Text(
          'Plan updated',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Your plan has been adjusted. Here's a note to keep you going.",
          style: TextStyle(color: Color(0xFF888888), fontSize: 13, height: 1.4),
        ),

        const SizedBox(height: 20),

        // Gemini message card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _amber.withValues(alpha: 0.25)),
          ),
          child: loadingGemini
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: _amber,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Personalising your message…',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: const Color(0xFF64FFDA), size: 20),
                    const SizedBox(height: 8),
                    Text(
                      geminiMessage ?? '',
                      style: const TextStyle(
                        color: Color(0xFFDDDDDD),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your adjustment',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                summaryLine1,
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summaryLine2,
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Done button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: onDone,
            child: const Text(
              "Got it, let's keep going →",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Disclaimer
// ---------------------------------------------------------------------------
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      "One high-calorie day is common and doesn't impact your long-term progress. "
      "This tool helps you gently adjust your plan while keeping calories within safe limits. "
      "We base adjustments on weekly averages and scientific estimates — real bodies vary. "
      "If you often feel out of control around food or feel compelled to constantly make adjustments after eating, "
      "consider talking to a doctor or mental health professional.",
      style: TextStyle(
        color: Color(0xFF555555),
        fontSize: 11,
        height: 1.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drag handle
// ---------------------------------------------------------------------------
class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
