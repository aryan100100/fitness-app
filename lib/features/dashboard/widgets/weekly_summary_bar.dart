// [HEALTH APP] — Weekly Summary Bar
// Subtle single line showing weekly calorie balance.
// Reminds users one day is part of a bigger picture.

import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';

class WeeklySummaryBar extends StatelessWidget {
  final double weeklyLogged;
  final double weeklyTarget;
  final int daysLogged;

  const WeeklySummaryBar({
    super.key,
    required this.weeklyLogged,
    required this.weeklyTarget,
    required this.daysLogged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'This week: ${weeklyLogged.round()} kcal / ${weeklyTarget.round()} kcal target ($daysLogged day${daysLogged == 1 ? '' : 's'} logged)',
        style: AppTextStyles.caption,
        textAlign: TextAlign.center,
      ),
    );
  }
}
