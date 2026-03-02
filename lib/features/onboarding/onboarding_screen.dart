// [HEALTH APP] — Onboarding Shell Screen
// Contains the PageView, progress indicator, and navigation logic.

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import 'onboarding_controller.dart';
import 'steps/step1_name.dart';
import 'steps/step2_bio.dart';
import 'steps/step3_goal.dart';
import 'steps/step4_activity.dart';
import 'steps/step5_life_situation.dart';
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
  static const int _totalSteps = 5;

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

  void _goToResults() {
    _controller.calculateResults();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondary) => ResultsScreen(controller: _controller),
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
                  // Back arrow (hidden on step 1)
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
                  // Spacer to balance back arrow
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
                  Step1Name(controller: _controller, onNext: _nextPage),
                  Step2Bio(controller: _controller, onNext: _nextPage),
                  Step3Goal(controller: _controller, onNext: _nextPage),
                  Step4Activity(controller: _controller, onNext: _nextPage),
                  Step5LifeSituation(
                    controller: _controller,
                    onFinish: _goToResults,
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
