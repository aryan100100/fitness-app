// [HEALTH APP] — Onboarding Shell Screen
// Updated for Feature 2: 6 steps, GoalPaceScreen routing.

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import 'onboarding_controller.dart';
import 'steps/step1_name.dart';
import 'steps/step2_bio.dart';
import 'steps/step3_goal.dart';
import 'steps/step4_body_fat.dart';
import 'steps/step5_activity.dart';
import 'steps/step6_life_situation.dart';
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
  static const int _totalSteps = 6;

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

  /// Called after Step 6 (life situation).
  /// For maintain goal: go straight to results.
  /// For lose/gain: show the goal pace slider screen first.
  void _onOnboardingComplete() {
    if (_controller.goal == 'maintain') {
      // No pace screen needed — calculate with 0 adjustment and show results.
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
        transitionsBuilder: (ctx, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _goToResults() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondary) =>
            ResultsScreen(controller: _controller),
        transitionsBuilder: (ctx, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
            // --- Top bar: back arrow + progress dots ---
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
                      dotColor: AppColors.divider,
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

            // --- Page content ---
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Step 1 — Name
                  Step1Name(controller: _controller, onNext: _nextPage),
                  // Step 2 — Bio (sex, DOB, height, weight)
                  Step2Bio(controller: _controller, onNext: _nextPage),
                  // Step 3 — Goal
                  Step3Goal(controller: _controller, onNext: _nextPage),
                  // Step 4 — Body fat (optional, new)
                  Step4BodyFat(controller: _controller, onNext: _nextPage),
                  // Step 5 — Activity level (was Step 4)
                  Step5Activity(controller: _controller, onNext: _nextPage),
                  // Step 6 — Life situation + region (was Step 5)
                  Step6LifeSituation(
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
