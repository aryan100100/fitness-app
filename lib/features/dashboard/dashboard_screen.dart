// [HEALTH APP] — Dashboard Screen (Placeholder for Feature 3)
// Person A will build this screen when developing Feature 3.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppColors.primaryAccent, size: 64),
            const SizedBox(height: 16),
            Text('Onboarding Complete!', style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            Text('Dashboard coming soon — Feature 3', style: AppTextStyles.bodySecondary),
          ],
        ),
      ),
    );
  }
}
