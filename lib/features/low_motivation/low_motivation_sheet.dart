// [HEALTH APP] — Low Motivation Sheet (Feature 8)
// Structured recovery tool. Validates struggle, offers flexible restraint options.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/low_motivation_service.dart';
import '../../models/user_model.dart';
import 'low_motivation_option_card.dart';
import 'values_reminder_card.dart';

class LowMotivationSheet extends StatefulWidget {
  final UserModel user;

  const LowMotivationSheet({super.key, required this.user});

  @override
  State<LowMotivationSheet> createState() => _LowMotivationSheetState();
}

class _LowMotivationSheetState extends State<LowMotivationSheet> {
  bool _isLoading = true;
  String _validationMessage = "You showed up, and that's what counts today.";
  bool _canUseMaintenance = true;
  LowMotivationFlag _flag = LowMotivationFlag.none;
  
  bool _showValuesReminder = false;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        LowMotivationService.instance.checkFlags(widget.user.id ?? ''),
        LowMotivationService.instance.canUseMaintenanceDay(widget.user.id ?? ''),
        GeminiService.instance.generateLowMotivationMessage(widget.user),
      ]);

      if (mounted) {
        setState(() {
          _flag = results[0] as LowMotivationFlag;
          _canUseMaintenance = results[1] as bool;
          final msg = results[2] as String?;
          if (msg != null && msg.isNotEmpty) {
            _validationMessage = msg;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOptionA() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);
    await LowMotivationService.instance.applyMinimumViableDay(widget.user);
    if (mounted) {
      setState(() {
        _isApplying = false;
        _showValuesReminder = true;
      });
    }
  }

  Future<void> _handleOptionB() async {
    if (_isApplying || !_canUseMaintenance) return;
    setState(() => _isApplying = true);
    await LowMotivationService.instance.applyMaintenanceDay(widget.user);
    if (mounted) {
      setState(() {
        _isApplying = false;
        _showValuesReminder = true;
      });
    }
  }

  Future<void> _handleOptionC() async {
    if (_isApplying) return;
    setState(() => _isApplying = true);
    await LowMotivationService.instance.logUsage(widget.user.id ?? '', 'Option C');
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _showValuesReminder 
                    ? _buildValuesReminder() 
                    : _buildMainContent(scrollCtrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValuesReminder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ValuesReminderCard(
          user: widget.user,
          onDone: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }

  Widget _buildMainContent(ScrollController scrollCtrl) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryAccent),
      );
    }

    final isStrongFlag = _flag == LowMotivationFlag.strong || _flag == LowMotivationFlag.clinical;

    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.battery_1_bar_rounded, color: AppColors.warning, size: 28),
              const SizedBox(width: 12),
              Text('Low Motivation Mode', style: AppTextStyles.headingMedium),
            ],
          ),
          const SizedBox(height: 24),

          // Gemini Validation Message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _validationMessage,
                    style: AppTextStyles.body.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Mild flag prompt
          if (_flag == LowMotivationFlag.mild) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       'You\'ve used this feature a few times recently. If your daily targets feel too high, consider adjusting your pace in Settings.',
                       style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                     ),
                   ),
                ],
              ),
            ),
          ],

          // Strong flag — disables A and B
          if (isStrongFlag) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                   const Icon(Icons.favorite, color: AppColors.destructive, size: 20),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       'You\'ve been struggling for several days. It might be time to take a proper diet break for a week or recalibrate your goals. We\'ve disabled the quick-fix options for today — please focus on rest.',
                       style: AppTextStyles.caption.copyWith(color: AppColors.destructive),
                     ),
                   ),
                ],
              ),
            ),
          ],

          // Options
          Text('Choose what feels doable today:', 
               style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          Opacity(
            opacity: isStrongFlag ? 0.4 : 1.0,
            child: LowMotivationOptionCard(
              title: 'Minimum Viable Day',
              description: 'Just log one protein-rich meal. We\'ll hide the calories and keep your streak alive. No pressure.',
              icon: Icons.done_all,
              isPrimary: true,
              onTap: isStrongFlag ? () {} : _handleOptionA,
            ),
          ),
          const SizedBox(height: 12),

          Opacity(
            opacity: (isStrongFlag || !_canUseMaintenance) ? 0.4 : 1.0,
            child: LowMotivationOptionCard(
              title: 'Maintenance Day${!_canUseMaintenance && !isStrongFlag ? ' (Limit Reached)' : ''}',
              description: 'Eat up to your maintenance calories (${widget.user.tdee.round()} kcal). Still a win for the long-term.',
              icon: Icons.pause_circle_outline,
              onTap: (isStrongFlag || !_canUseMaintenance) ? () {} : _handleOptionB,
            ),
          ),
          const SizedBox(height: 12),

          LowMotivationOptionCard(
            title: 'I\'ll Keep Going',
            description: 'Actually, reading this helped. I\'ll stick to my original plan for today.',
            icon: Icons.directions_run,
            onTap: _handleOptionC,
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
