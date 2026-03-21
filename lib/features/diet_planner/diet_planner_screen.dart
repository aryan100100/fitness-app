// [HEALTH APP] — Diet Planner Screen (Tab Shell)
// Top-level screen for Tab 2 (🤖). Contains two tabs: Meal Plan | Recipe.
// Receives UserModel from nav_shell so both tabs have access to user data.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import 'meal_plan_tab.dart';
import 'recipe_tab.dart';

class DietPlannerScreen extends StatelessWidget {
  final UserModel user;
  const DietPlannerScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 0, // no title bar — tabs sit at the top
          bottom: TabBar(
            indicatorColor: AppColors.primaryAccent,
            indicatorWeight: 3.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Meal Plan'),
              Tab(text: 'Recipe'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MealPlanTab(user: user),
            RecipeTab(user: user),
          ],
        ),
      ),
    );
  }
}
