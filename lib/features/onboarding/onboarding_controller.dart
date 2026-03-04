// [HEALTH APP] — Onboarding Controller (State Management)
// Single ChangeNotifier holding all user data across 6 onboarding steps.
// Updated for Feature 2: body fat range + pace slider + NutritionPlan.

import 'package:flutter/material.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/services/supabase_service.dart';
import '../../models/user_model.dart';

class OnboardingController extends ChangeNotifier {
  // --- Step 1 ---
  String name = '';

  // --- Step 2 ---
  String biologicalSex = 'male';
  DateTime? dateOfBirth;
  double heightCm = 170;
  double weightKg = 70;

  // --- Step 3 ---
  String goal = ''; // 'lose' | 'gain' | 'maintain'
  double? targetWeightKg;

  // --- Step 4 (old) → now Step 5 ---
  String activityLevel = '';

  // --- Step 4 (NEW — body fat) ---
  String? bodyFatRange;   // null = skipped
  bool bodyFatSkipped = false;

  // --- Step 6 (old Step 5) ---
  String lifeSituation = '';
  String region = 'India';

  // --- Pace slider state (set on GoalPaceScreen) ---
  // Default: 0.75% for loss, 0.25% for gain. Set by GoalPaceScreen before calculateAll().
  double weeklyPacePercent = 0.75;

  // --- Computed result (populated after GoalPaceScreen confirms) ---
  NutritionPlan? nutritionPlan;

  bool isSaving = false;
  String? saveError;

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  int get age {
    if (dateOfBirth == null) return 22;
    return DateHelpers.ageFromDob(dateOfBirth!);
  }

  /// Default pace based on goal — used as slider initial value.
  double get defaultPacePercent => goal == 'gain' ? 0.25 : 0.75;

  // ---------------------------------------------------------------------------
  // Step validation
  // ---------------------------------------------------------------------------
  bool get step1Valid => name.trim().isNotEmpty;
  bool get step2Valid => dateOfBirth != null && heightCm > 0 && weightKg > 0;
  bool get step3Valid => goal.isNotEmpty;
  bool get step4Valid => true; // body fat is always optional
  bool get step5Valid => activityLevel.isNotEmpty;
  bool get step6Valid => lifeSituation.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Calculate full NutritionPlan using current state.
  // Called right before navigating to ResultsScreen.
  // ---------------------------------------------------------------------------
  void calculateAll() {
    // Build a temporary UserModel from current controller state.
    final user = _buildUserModel(
      tdee: 0, targetCalories: 0,
      proteinG: 0, carbsG: 0, fatG: 0, fiberG: 0,
    );
    nutritionPlan = TDEECalculator.calculateAll(
      user: user,
      weeklyPacePercent: weeklyPacePercent,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Save the full NutritionPlan to Supabase. Returns true on success.
  // Called by ResultsScreen on "Let's Start →" tap.
  // ---------------------------------------------------------------------------
  Future<bool> saveToSupabase() async {
    if (nutritionPlan == null) return false;
    isSaving = true;
    saveError = null;
    notifyListeners();

    try {
      final plan = nutritionPlan!;
      final today = DateHelpers.todayString();
      final user = _buildUserModel(
        tdee: plan.tdee,
        targetCalories: plan.targetCalories,
        proteinG: plan.proteinG,
        carbsG: plan.carbsG,
        fatG: plan.fatG,
        fiberG: plan.fiberG,
        goalStartDate: today,
        goalEndDate: plan.goalEndDate != null
            ? DateHelpers.formatDate(plan.goalEndDate!)
            : null,
        weeklyPacePercent: plan.weeklyPacePercent,
        dailyDeficitSurplus: plan.dailyDeficitSurplus,
      );
      await SupabaseService.instance.createUser(user);
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      isSaving = false;
      saveError = 'Could not save your profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helper — builds a UserModel from current controller state.
  // ---------------------------------------------------------------------------
  UserModel _buildUserModel({
    required double tdee,
    required double targetCalories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double fiberG,
    String? goalStartDate,
    String? goalEndDate,
    double? weeklyPacePercent,
    double? dailyDeficitSurplus,
  }) {
    return UserModel(
      name: name.trim(),
      age: age,
      biologicalSex: biologicalSex,
      heightCm: heightCm,
      weightKg: weightKg,
      targetWeightKg: targetWeightKg,
      goal: goal,
      activityLevel: activityLevel.isEmpty ? 'sedentary' : activityLevel,
      lifeSituation: lifeSituation.isEmpty ? 'other' : lifeSituation,
      region: region,
      tdee: tdee,
      targetCalories: targetCalories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fiberG: fiberG,
      goalStartDate: goalStartDate,
      goalEndDate: goalEndDate,
      foodPreferences: const [],
      bodyFatRange: bodyFatRange,
      weeklyPacePercent: weeklyPacePercent,
      dailyDeficitSurplus: dailyDeficitSurplus,
    );
  }

  // ---------------------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------------------
  void setName(String v)          { name = v; notifyListeners(); }
  void setSex(String v)           { biologicalSex = v; notifyListeners(); }
  void setDob(DateTime v)         { dateOfBirth = v; notifyListeners(); }
  void setHeight(double v)        { heightCm = v; notifyListeners(); }
  void setWeight(double v)        { weightKg = v; notifyListeners(); }
  void setGoal(String v) {
    goal = v;
    weeklyPacePercent = v == 'gain' ? 0.25 : 0.75; // reset default
    if (v == 'maintain') targetWeightKg = null;
    notifyListeners();
  }
  void setTargetWeight(double v)  { targetWeightKg = v; notifyListeners(); }
  void setBodyFatRange(String? v) { bodyFatRange = v; bodyFatSkipped = false; notifyListeners(); }
  void skipBodyFat()              { bodyFatRange = null; bodyFatSkipped = true; notifyListeners(); }
  void setActivityLevel(String v) { activityLevel = v; notifyListeners(); }
  void setLifeSituation(String v) { lifeSituation = v; notifyListeners(); }
  void setRegion(String v)        { region = v; notifyListeners(); }
  void setPacePercent(double v)   { weeklyPacePercent = v; notifyListeners(); }
}
