// [HEALTH APP] — Onboarding Shell Screen
// Updated for Feature 1 Update: 8 steps.
// Step order: Name → Bio → Goal → Activity → Body Fat → Protein Pref → Life Situation → Lifting

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import 'onboarding_controller.dart';
import 'steps/step1_name.dart';
import 'steps/step2_bio.dart';
import 'steps/step3_goal.dart';
import 'steps/step4_activity.dart';
import 'steps/step5_body_fat.dart';
import 'steps/step6_protein_preference.dart';
import 'steps/step7_life_situation.dart';
import 'steps/step8_lifting_experience.dart';
import 'goal_pace_screen.dart';
import 'results_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingController _controller = OnboardingController();
  int _currentPage = 0;
  static const int _totalSteps = 8;

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Called after Step 8 (lifting experience).
  /// For maintain goal: calculate with 0 adjustment and go straight to results.
  /// For lose/gain: show goal pace slider first.
  void _onOnboardingComplete() {
    if (_controller.goal == 'maintain') {
      _controller.setPacePercent(0);
      _controller.calculateAll();
      _goToResults();
    } else {
      _goToGoalPaceScreen();
    }
  }

  void _goToGoalPaceScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondary) =>
            GoalPaceScreen(controller: _controller),
        transitionsBuilder: (ctx, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _goToResults() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondary) =>
            ResultsScreen(controller: _controller),
        transitionsBuilder: (ctx, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- Top bar: back arrow + 8 progress dots ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: _currentPage > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _previousPage,
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _totalSteps,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: AppColors.primaryAccent,
                      dotColor: AppColors.subtleBorder,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // --- 8-step PageView ---
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Step 1 — Name
                  Step1Name(controller: _controller, onNext: _nextPage),
                  // Step 2 — Bio
                  Step2Bio(controller: _controller, onNext: _nextPage),
                  // Step 3 — Goal
                  Step3Goal(controller: _controller, onNext: _nextPage),
                  // Step 4 — Activity Level
                  Step4Activity(controller: _controller, onNext: _nextPage),
                  // Step 5 — Body Fat Range (optional)
                  Step5BodyFat(controller: _controller, onNext: _nextPage),
                  // Step 6 — Protein Preference (pre-selected: moderate)
                  Step6ProteinPreference(
                      controller: _controller, onNext: _nextPage),
                  // Step 7 — Life Situation + Region
                  Step7LifeSituation(
                      controller: _controller, onNext: _nextPage),
                  // Step 8 — Lifting Experience (no default)
                  Step8LiftingExperience(
                    controller: _controller,
                    onFinish: _onOnboardingComplete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
