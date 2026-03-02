// [HEALTH APP] — Onboarding Step 1: Name Input

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/primary_button.dart';
import '../onboarding_controller.dart';

class Step1Name extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback onNext;

  const Step1Name({super.key, required this.controller, required this.onNext});

  @override
  State<Step1Name> createState() => _Step1NameState();
}

class _Step1NameState extends State<Step1Name>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _textController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.name);
    _textController.addListener(() {
      widget.controller.setName(_textController.text);
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(_fadeAnim);
  }

  @override
  void dispose() {
    _textController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text('Hey there 👋', style: AppTextStyles.headingLarge),
              const SizedBox(height: 8),
              Text(
                'What should we call you?',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _textController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'Your first name',
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppColors.secondaryText),
                ),
                onSubmitted: (_) {
                  if (widget.controller.step1Valid) widget.onNext();
                },
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: widget.controller,
                builder: (context, child) => PrimaryButton(
                  label: 'Continue',
                  onTap: widget.controller.step1Valid ? widget.onNext : null,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
