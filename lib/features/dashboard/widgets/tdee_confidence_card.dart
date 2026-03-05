// [HEALTH APP] — TDEE Confidence Card
// Shows calibration status: building / calibrated / inconsistent.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/dashboard_summary.dart';
import '../../../widgets/app_card.dart';

class TDEEConfidenceCard extends StatelessWidget {
  final TDEEConfidence confidence;
  final int daysLogged;

  const TDEEConfidenceCard({
    super.key,
    required this.confidence,
    required this.daysLogged,
  });

  @override
  Widget build(BuildContext context) {
    return switch (confidence) {
      TDEEConfidence.calibrated   => _CalibrationCard(confidence),
      TDEEConfidence.inconsistent => _CalibrationCard(confidence),
      TDEEConfidence.building     => _BuildingCard(daysLogged),
    };
  }
}

class _BuildingCard extends StatelessWidget {
  final int daysLogged;
  const _BuildingCard(this.daysLogged);

  @override
  Widget build(BuildContext context) {
    final progress = (daysLogged / 14).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'TDEE Confidence: Building...',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Log consistently for 14 days and we\'ll refine your calorie target using your real data.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$daysLogged/14 days',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  final TDEEConfidence state;
  const _CalibrationCard(this.state);

  @override
  Widget build(BuildContext context) {
    final isCalibrated = state == TDEEConfidence.calibrated;
    final color =
        isCalibrated ? AppColors.primaryAccent : AppColors.warning;
    final icon = isCalibrated ? '✅' : '⚠️';
    final message = isCalibrated
        ? 'TDEE Calibrated — Your targets are refined from your real progress data.'
        : 'Log more consistently to unlock your personalised TDEE calibration.';

    return AppCard(
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
