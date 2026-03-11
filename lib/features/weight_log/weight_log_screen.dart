// [HEALTH APP] — Weight Log Screen (Feature 7)
// Used by Situations 1, 3, 4, and from Profile tab.
// Female users see menstrual toggle. Unit toggle kg/lbs.
// Saves and optionally triggers weekly recalc if today is check-in day.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/auto_adjustment_service.dart';
import '../../../core/services/weight_log_service.dart';
import '../../../models/user_model.dart';
import 'weight_history_chart.dart';
import '../../../models/weight_log_model.dart';

class WeightLogScreen extends StatefulWidget {
  final UserModel user;
  /// When true, shows a back-arrow in the app bar (for modal/push nav).
  /// When false (default), used as a tab — no back button.
  final bool showBackButton;
  const WeightLogScreen({super.key, required this.user, this.showBackButton = false});

  @override
  State<WeightLogScreen> createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends State<WeightLogScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool _isMenstrual = false;
  bool _saving = false;
  bool _useLbs = false;

  List<WeightLog> _entries = [];
  bool _loadingEntries = true;

  // Weekly stats
  double? _thisWeekAvg;
  double? _prevWeekAvg;

  static const _lbs = 2.20462;

  @override
  void initState() {
    super.initState();
    _useLbs = widget.user.weightUnit == 'lbs';
    _loadData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = widget.user.id ?? '';
    final entries =
        await WeightLogService.instance.getRecentWeights(userId, days: 60);
    final thisWeek =
        await WeightLogService.instance.getCurrentWeeklyAverage(userId);
    final prevWeek =
        await WeightLogService.instance.getPreviousWeeklyAverage(userId);

    if (mounted) {
      setState(() {
        _entries = entries;
        _thisWeekAvg = thisWeek;
        _prevWeekAvg = prevWeek;
        _loadingEntries = false;
      });
    }
  }

  Future<void> _save() async {
    final raw = double.tryParse(_ctrl.text.trim());
    if (raw == null || raw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid weight'),
        backgroundColor: Color(0xFF2A2A2A),
      ));
      return;
    }

    // Convert lbs → kg if needed
    final weightKg = _useLbs ? raw / _lbs : raw;

    if (weightKg < 20 || weightKg > 300) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Weight seems outside a typical range — please check the value'),
        backgroundColor: Color(0xFF2A2A2A),
      ));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final userId = widget.user.id ?? '';
      await WeightLogService.instance.saveWeight(
        userId,
        weightKg,
        isMenstrual: _isMenstrual,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Weight saved ✅'),
        backgroundColor: Color(0xFF1B3A27),
        behavior: SnackBarBehavior.floating,
      ));

      _ctrl.clear();
      await _loadData();

      // If today is check-in day, run weekly recalc
      final isCheckinDay =
          DateTime.now().weekday == widget.user.checkinDay;
      if (isCheckinDay) {
        final result = await AutoAdjustmentService.instance.runWeeklyRecalc(
          widget.user.copyWith(weightKg: weightKg),
        );
        if (mounted && result.outcome != RecalcOutcome.insufficientData) {
          _showRecalcSnackbar(result);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save weight. Please try again. ($e)'),
          backgroundColor: Colors.red.shade900,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showRecalcSnackbar(WeeklyRecalcResult result) {
    final msg = switch (result.outcome) {
      RecalcOutcome.stable => '⚖️ Weight stable — no target changes needed',
      RecalcOutcome.menstrualSkip => '💛 Weekly update paused this week',
      RecalcOutcome.insufficientData =>
        '📊 Log a few more times for a weekly update',
      RecalcOutcome.smallChange => '✅ Targets fine-tuned based on this week',
      _ => '📊 Weekly check-in complete — see dashboard for details',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2A2A2A),
      behavior: SnackBarBehavior.floating,
    ));
  }

  double? get _changeThisWeek {
    if (_thisWeekAvg == null || _prevWeekAvg == null) return null;
    return _thisWeekAvg! - _prevWeekAvg!;
  }

  double? get _changeSinceStart {
    if (_thisWeekAvg == null) return null;
    return _thisWeekAvg! - widget.user.weightKg;
  }

  double _displayWeight(double kg) => _useLbs ? kg * _lbs : kg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Log Your Weight', style: AppTextStyles.body),
        leading: widget.showBackButton
            ? const BackButton(color: AppColors.primaryText)
            : null,
        automaticallyImplyLeading: false,
        actions: [
          // kg / lbs toggle
          GestureDetector(
            onTap: () => setState(() => _useLbs = !_useLbs),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _useLbs ? 'lbs' : 'kg',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryAccent),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weight input
              _WeightInput(
                controller: _ctrl,
                focus: _focus,
                unit: _useLbs ? 'lbs' : 'kg',
              ),

              const SizedBox(height: 8),
              const Text(
                'Best results: weigh yourself in the morning, after using the bathroom, before eating, in minimal clothing — same conditions every day.',
                style: TextStyle(
                    color: Color(0xFF666666), fontSize: 11, height: 1.5),
              ),

              // Menstrual toggle (female only)
              if (widget.user.biologicalSex == 'female') ...[
                const SizedBox(height: 16),
                _MenstrualToggle(
                  value: _isMenstrual,
                  onChanged: (v) => setState(() => _isMenstrual = v),
                ),
              ],

              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Weight',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),

              const SizedBox(height: 24),

              // Chart
              Text('Your Weight Trend',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _loadingEntries
                  ? const SizedBox(
                      height: 160,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF4CAF50), strokeWidth: 2)))
                  : WeightHistoryChart(
                      entries: _entries,
                      unit: _useLbs ? 'lbs' : 'kg',
                    ),

              const SizedBox(height: 20),

              // Weekly stats 2x2
              if (!_loadingEntries) _WeeklyStats(
                thisWeekAvg: _thisWeekAvg,
                changeThisWeek: _changeThisWeek,
                changeSinceStart: _changeSinceStart,
                dailyDeficit: widget.user.dailyDeficitSurplus ?? 0,
                displayFn: _displayWeight,
                unit: _useLbs ? 'lbs' : 'kg',
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight input widget
// ---------------------------------------------------------------------------
class _WeightInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String unit;

  const _WeightInput(
      {required this.controller,
      required this.focus,
      required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '0.0',
                hintStyle: const TextStyle(
                    color: Color(0xFF3A3A3A), fontSize: 32),
                border: InputBorder.none,
              ),
            ),
          ),
          Text(unit,
              style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 20,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menstrual toggle
// ---------------------------------------------------------------------------
class _MenstrualToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MenstrualToggle(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFFB300),
            ),
            const SizedBox(width: 8),
            const Text(
              "I'm on my period right now",
              style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13),
            ),
          ],
        ),
        if (value)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFFB300).withOpacity(0.3)),
            ),
            child: const Text(
              "Weight often increases 1–3 kg during your period due to water retention — this is completely normal and not a change in body composition. We'll account for this when updating your targets.",
              style: TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 11, height: 1.5),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly stats 2×2 grid
// ---------------------------------------------------------------------------
class _WeeklyStats extends StatelessWidget {
  final double? thisWeekAvg;
  final double? changeThisWeek;
  final double? changeSinceStart;
  final double dailyDeficit;
  final double Function(double) displayFn;
  final String unit;

  const _WeeklyStats({
    required this.thisWeekAvg,
    required this.changeThisWeek,
    required this.changeSinceStart,
    required this.dailyDeficit,
    required this.displayFn,
    required this.unit,
  });

  String _fmt(double? v, {bool sign = false}) {
    if (v == null) return '—';
    final d = displayFn(v.abs());
    final prefix = sign ? (v < 0 ? '-' : '+') : '';
    return '$prefix${d.toStringAsFixed(1)} $unit';
  }

  // Expected weekly change from deficit
  double get _expectedPerWeek =>
      dailyDeficit.abs() * 7 / 7700;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _StatTile('This week\'s average', _fmt(thisWeekAvg)),
        _StatTile(
          'Change this week',
          _fmt(changeThisWeek, sign: true),
          valueColor: changeThisWeek != null && changeThisWeek! < 0
              ? const Color(0xFF4CAF50)
              : null,
        ),
        _StatTile(
          'Change since start',
          _fmt(changeSinceStart, sign: true),
        ),
        _StatTile(
          'Expected per week',
          '~${displayFn(_expectedPerWeek).toStringAsFixed(1)} $unit',
          subtitle: 'from your current plan',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? subtitle;

  const _StatTile(this.label, this.value,
      {this.valueColor, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF888888), fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFFE0E0E0),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 9)),
        ],
      ),
    );
  }
}
