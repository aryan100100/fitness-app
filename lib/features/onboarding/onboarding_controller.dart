// [HEALTH APP] — Onboarding Controller (State Management)
// Single ChangeNotifier that holds all user data collected across the 5 steps.
// On step 5 completion it calculates TDEE + macros and saves to Supabase.

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

  // --- Step 4 ---
  String activityLevel = ''; // 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active'

  // --- Step 5 ---
  String lifeSituation = ''; // 'hostel_student' | 'office_worker' | 'work_from_home' | 'homemaker' | 'other'
  String region = 'India';

  // --- Computed results (populated after step 5) ---
  TdeeResult? result;

  bool isSaving = false;
  String? saveError;

  int get age {
    if (dateOfBirth == null) return 22; // sensible default
    return DateHelpers.ageFromDob(dateOfBirth!);
  }

  bool get step1Valid => name.trim().isNotEmpty;
  bool get step2Valid => dateOfBirth != null && heightCm > 0 && weightKg > 0;
  bool get step3Valid => goal.isNotEmpty;
  bool get step4Valid => activityLevel.isNotEmpty;
  bool get step5Valid => lifeSituation.isNotEmpty;

  /// Must be called at the end of step 5 before showing the results screen.
  void calculateResults() {
    result = TdeeCalculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      biologicalSex: biologicalSex,
      activityLevel: activityLevel,
      goal: goal,
    );
    notifyListeners();
  }

  /// Saves the full user profile to Supabase and returns true on success.
  Future<bool> saveToSupabase() async {
    if (result == null) return false;
    isSaving = true;
    saveError = null;
    notifyListeners();

    try {
      final today = DateHelpers.todayString();
      final user = UserModel(
        name: name.trim(),
        age: age,
        biologicalSex: biologicalSex,
        heightCm: heightCm,
        weightKg: weightKg,
        targetWeightKg: targetWeightKg,
        goal: goal,
        activityLevel: activityLevel,
        lifeSituation: lifeSituation,
        region: region,
        tdee: result!.tdee,
        targetCalories: result!.targetCalories,
        proteinG: result!.macros.protein,
        carbsG: result!.macros.carbs,
        fatG: result!.macros.fat,
        fiberG: result!.macros.fiber,
        goalStartDate: today,
        foodPreferences: const [],
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

  void setName(String v) { name = v; notifyListeners(); }
  void setSex(String v) { biologicalSex = v; notifyListeners(); }
  void setDob(DateTime v) { dateOfBirth = v; notifyListeners(); }
  void setHeight(double v) { heightCm = v; notifyListeners(); }
  void setWeight(double v) { weightKg = v; notifyListeners(); }
  void setGoal(String v) { goal = v; if (v == 'maintain') targetWeightKg = null; notifyListeners(); }
  void setTargetWeight(double v) { targetWeightKg = v; notifyListeners(); }
  void setActivityLevel(String v) { activityLevel = v; notifyListeners(); }
  void setLifeSituation(String v) { lifeSituation = v; notifyListeners(); }
  void setRegion(String v) { region = v; notifyListeners(); }
}
