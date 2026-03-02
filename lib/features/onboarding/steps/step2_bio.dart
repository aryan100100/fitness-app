// [HEALTH APP] — Onboarding Step 2: Bio Data
// Sex toggle, date of birth, height slider, weight input.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step2Bio extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step2Bio({super.key, required this.controller, required this.onNext});

  @override
  State<Step2Bio> createState() => _Step2BioState();
}

class _Step2BioState extends State<Step2Bio> {
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
        text: widget.controller.weightKg.toStringAsFixed(0));
    _heightController = TextEditingController(
        text: widget.controller.heightCm.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.controller.dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 22)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryAccent,
            surface: AppColors.cardSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) widget.controller.setDob(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final ctrl = widget.controller;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('Tell us about you', style: AppTextStyles.headingLarge),
              const SizedBox(height: 6),
              Text('This helps us calculate your exact calorie needs.',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 32),

              // --- Sex toggle ---
              Text('Biological Sex', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  _SexToggle(
                    label: 'Male',
                    icon: Icons.male,
                    selected: ctrl.biologicalSex == 'male',
                    onTap: () => ctrl.setSex('male'),
                  ),
                  const SizedBox(width: 12),
                  _SexToggle(
                    label: 'Female',
                    icon: Icons.female,
                    selected: ctrl.biologicalSex == 'female',
                    onTap: () => ctrl.setSex('female'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Date of birth ---
              Text('Date of Birth', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.secondaryText, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        ctrl.dateOfBirth != null
                            ? '${ctrl.dateOfBirth!.day}/${ctrl.dateOfBirth!.month}/${ctrl.dateOfBirth!.year}  •  Age ${ctrl.age}'
                            : 'Select your date of birth',
                        style: ctrl.dateOfBirth != null
                            ? AppTextStyles.body
                            : AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Height slider ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Height', style: AppTextStyles.caption),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: ctrl.heightCm.toStringAsFixed(0),
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.primaryAccent,
                              fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text: ' cm', style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryAccent,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor: AppColors.primaryAccent,
                  overlayColor:
                      AppColors.primaryAccent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: ctrl.heightCm,
                  min: 120,
                  max: 220,
                  divisions: 100,
                  onChanged: ctrl.setHeight,
                ),
              ),
              const SizedBox(height: 16),

              // --- Weight input ---
              Text('Current weight (kg)', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepperButton(
                    icon: Icons.remove,
                    onTap: () {
                      if (ctrl.weightKg > 30) {
                        ctrl.setWeight(ctrl.weightKg - 0.5);
                        _weightController.text =
                            ctrl.weightKg.toStringAsFixed(1);
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                          hintText: '70', suffixText: 'kg'),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) ctrl.setWeight(parsed);
                      },
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.add,
                    onTap: () {
                      ctrl.setWeight(ctrl.weightKg + 0.5);
                      _weightController.text =
                          ctrl.weightKg.toStringAsFixed(1);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),

              PrimaryButton(
                label: 'Continue',
                onTap: ctrl.step2Valid ? onNext : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  VoidCallback get onNext => widget.onNext;
}

class _SexToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SexToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryAccent.withValues(alpha: 0.15)
                : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryAccent : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected
                      ? AppColors.primaryAccent
                      : AppColors.secondaryText,
                  size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: AppTextStyles.body.copyWith(
                      color: selected
                          ? AppColors.primaryAccent
                          : AppColors.secondaryText,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.primaryAccent),
      ),
    );
  }
}
