// [HEALTH APP] — Divergence Diagnostic Card (Feature 7, Situation 5)
// Shows when actual weight diverges 15%+ from predicted.
// Multi-select checklist before recommending any action.

import 'package:flutter/material.dart';
import '../../../../core/services/auto_adjustment_service.dart';
import 'adjustment_card.dart';

class DivergenceDiagnosticCard extends StatefulWidget {
  final DivergenceResult result;
  final bool isFemale;
  final VoidCallback onDismiss;
  final VoidCallback onRequestRecalibration;
  final VoidCallback onSnooze;

  const DivergenceDiagnosticCard({
    super.key,
    required this.result,
    required this.isFemale,
    required this.onDismiss,
    required this.onRequestRecalibration,
    required this.onSnooze,
  });

  @override
  State<DivergenceDiagnosticCard> createState() =>
      _DivergenceDiagnosticCardState();
}

class _DivergenceDiagnosticCardState extends State<DivergenceDiagnosticCard> {
  final Set<String> _selected = {};
  bool _submitted = false;

  static const _items = [
    ('less_active', "I've been less active than usual"),
    ('salty_food', "I've had a lot of salty or higher-carb food recently"),
    ('ill_stressed', "I've been under the weather or dealing with extra stress"),
    ('inaccurate', "Some of my food logs might not be fully accurate"),
    ('none', "None of these — my logs seem accurate"),
  ];

  static const _menstrualItem =
      ('menstrual', "I'm close to or in my period");

  List<(String, String)> get _allItems => widget.isFemale
      ? [_items[0], _items[1], _menstrualItem, _items[2], _items[3], _items[4]]
      : _items.toList();

  bool get _noneSelected => _selected.contains('none');
  bool get _anythingExceptNone =>
      _selected.any((s) => s != 'none') && !_noneSelected;

  void _toggle(String id) {
    setState(() {
      if (id == 'none') {
        _selected.clear();
        _selected.add('none');
      } else {
        _selected.remove('none');
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.result;

    return AdjustmentCard(
      borderColor: const Color(0xFFFFB300),
      icon: Icons.bar_chart_rounded,
      title: "Your progress looks a little different from what we predicted",
      body:
          "Expected change so far: ${d.expectedChangeKg.abs().toStringAsFixed(1)} kg\n"
          "Actual change so far: ${d.actualChangeKg.abs().toStringAsFixed(1)} kg\n\n"
          "Before adjusting anything, let's check a few things:",
      onDismiss: widget.onDismiss,
      extraContent: _submitted ? _result() : _checklist(),
      actions: const [],
    );
  }

  Widget _checklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._allItems.map((item) {
          final (id, label) = item;
          final isSelected = _selected.contains(id);
          return GestureDetector(
            onTap: () => _toggle(id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFB300).withValues(alpha: 0.08)
                    : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF3A3A3A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: isSelected
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF555555),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFE0E0E0)
                              : const Color(0xFF888888),
                          fontSize: 12,
                          height: 1.3,
                        )),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          CardActionButton(
            label: 'Continue',
            onTap: () => setState(() => _submitted = true),
          ),
        ],
      ],
    );
  }

  Widget _result() {
    if (_anythingExceptNone) {
      // Contextual factors selected — snooze
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "These factors can all affect weight without any change in actual progress. "
            "Let's give it one more week before considering any adjustments.",
            style: TextStyle(
                color: Color(0xFFAAAAAA), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          CardActionButton(
            label: 'Check again next week',
            onTap: () {
              widget.onSnooze();
              widget.onDismiss();
            },
          ),
        ],
      );
    } else {
      // None selected — suggest recalibration
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Based on your actual results, your body may respond a little differently to the current plan. "
            "A recalibration would suggest updated targets based on what's actually worked.",
            style: TextStyle(
                color: Color(0xFFAAAAAA), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 10),
          CardActionButton(
            label: 'Review recalibration suggestion',
            onTap: () {
              widget.onRequestRecalibration();
              widget.onDismiss();
            },
          ),
          const SizedBox(height: 6),
          CardActionButton(
            label: 'Keep current targets',
            onTap: widget.onDismiss,
            isPrimary: false,
          ),
        ],
      );
    }
  }
}
