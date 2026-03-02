// [HEALTH APP] — Onboarding Step 3: Goal Selection

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step3Goal extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step3Goal({super.key, required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('What\'s your goal?', style: AppTextStyles.headingLarge),
              const SizedBox(height: 6),
              Text('We\'ll build your plan around this.',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 32),

              _GoalCard(
                emoji: '🎯',
                title: 'Lose Weight',
                subtitle: 'Create a sustainable calorie deficit',
                value: 'lose',
                selected: controller.goal == 'lose',
                onTap: () => controller.setGoal('lose'),
              ),
              const SizedBox(height: AppSpacing.cardSpacing),

              _GoalCard(
                emoji: '💪',
                title: 'Gain Weight',
                subtitle: 'Build muscle with a clean lean bulk',
                value: 'gain',
                selected: controller.goal == 'gain',
                onTap: () => controller.setGoal('gain'),
              ),
              const SizedBox(height: AppSpacing.cardSpacing),

              _GoalCard(
                emoji: '⚖️',
                title: 'Maintain Weight',
                subtitle: 'Stay at your current weight',
                value: 'maintain',
                selected: controller.goal == 'maintain',
                onTap: () => controller.setGoal('maintain'),
              ),

              // Target weight input — only visible for lose/gain
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: controller.goal == 'lose' || controller.goal == 'gain'
                    ? Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _TargetWeightInput(controller: controller),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Continue',
                onTap: controller.step3Valid ? onNext : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      isSelected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle,
                color: AppColors.primaryAccent, size: 22),
        ],
      ),
    );
  }
}

class _TargetWeightInput extends StatefulWidget {
  final OnboardingController controller;
  const _TargetWeightInput({required this.controller});

  @override
  State<_TargetWeightInput> createState() => _TargetWeightInputState();
}

class _TargetWeightInputState extends State<_TargetWeightInput> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.targetWeightKg?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Target weight (kg)', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: widget.controller.goal == 'lose'
                ? 'e.g. 65'
                : 'e.g. 80',
            suffixText: 'kg',
            prefixIcon: const Icon(Icons.flag_outlined,
                color: AppColors.secondaryText),
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) widget.controller.setTargetWeight(parsed);
          },
        ),
      ],
    );
  }
}
