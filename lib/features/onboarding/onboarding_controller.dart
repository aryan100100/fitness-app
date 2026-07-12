// [HEALTH APP] — Onboarding Controller (State Management)
// Single ChangeNotifier holding all user data across 8 onboarding steps.
// Updated for Feature 1 Update: protein preference + lifting experience.
// Updated for Feature 12: user is already authenticated when reaching onboarding.
// Removed anonymous auth — saveToSupabase() uses the existing auth session.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // --- Step 4 — Activity Level ---
  String activityLevel = '';

  // --- Step 5 — Body Fat Range (optional, new in Feature 2) ---
  String? bodyFatRange;   // null = skipped
  bool bodyFatSkipped = false;

  // --- Step 6 — Protein Preference (pre-selected: moderate) ---
  String proteinPreference = 'moderate';

  // --- Step 7 — Life Situation + Region ---
  String lifeSituation = '';
  String region = 'India';

  // --- Step 8 — Lifting Experience (no default, must be chosen) ---
  String liftingExperience = '';

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
  bool get step4Valid => activityLevel.isNotEmpty;     // Step 4: Activity Level
  bool get step5Valid => true;                          // Step 5: Body Fat — always optional
  bool get step6Valid => true;                          // Step 6: Protein Pref — pre-selected
  bool get step7Valid => lifeSituation.isNotEmpty;     // Step 7: Life Situation
  bool get step8Valid => liftingExperience.isNotEmpty; // Step 8: Lifting (no default)

  // ---------------------------------------------------------------------------
  // Calculate full NutritionPlan using current state.
  // Called right before navigating to ResultsScreen.
  // ---------------------------------------------------------------------------
  void calculateAll() {
    // Build a temporary UserModel from current controller state.
    // id is empty string — this model is only used for TDEE math, never saved.
    final user = _buildUserModel(
      id: '',
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
  // Save the full NutritionPlan to Supabase. Returns UserModel on success, null on error.
  // Called by ResultsScreen on "Let's Start →" tap.
  //
  // Auth strategy: anonymous sign-in via Supabase.
  // This gives the user a real auth.uid() immediately, satisfying the RLS
  // INSERT policy which requires: id = auth.uid().
  // ---------------------------------------------------------------------------
  Future<UserModel?> saveToSupabase({BuildContext? context}) async {
    if (nutritionPlan == null) return null;
    isSaving = true;
    saveError = null;
    notifyListeners();

    try {
      // -----------------------------------------------------------------------
      // Step 1 — User is already authenticated (via Google, Apple, or email)
      //          from the Welcome/Auth screen. Grab the existing session UID.
      // -----------------------------------------------------------------------
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser == null) {
        throw AuthException('No authenticated session found. Please sign in again.');
      }

      debugPrint('[ONBOARDING] Saving profile for UID: ${currentUser.id}');
      final uid = currentUser.id;

      // -----------------------------------------------------------------------
      // Step 2 — Build the user model with the auth UID as the users.id.
      // -----------------------------------------------------------------------
      final plan = nutritionPlan!;
      final today = DateHelpers.todayString();
      final user = _buildUserModel(
        id: uid,
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
        proteinMultiplier: plan.proteinMultiplier,
      );

      // Debug: print what we're inserting
      if (kDebugMode) {
        debugPrint('[UPSERT] Sending to users table:');
        user.toJson().forEach((k, v) => debugPrint('  $k: $v'));
      }

      // -----------------------------------------------------------------------
      // Step 3 — Upsert (not insert). Safe on re-run: updates existing row.
      // -----------------------------------------------------------------------
      await SupabaseService.instance.upsertUser(user);

      // -----------------------------------------------------------------------
      // Step 4 — Verify the row actually exists in Supabase.
      // -----------------------------------------------------------------------
      final verified = await SupabaseService.instance.verifyUserExists(uid);
      if (!verified) {
        throw Exception('Row verification unsuccessful — upsert appeared to succeed '
            'but the row could not be read back. Check RLS SELECT policy.');
      }

      debugPrint('[UPSERT] User row verified in Supabase. UID: $uid');
      isSaving = false;
      notifyListeners();
      return user;

    } on AuthException catch (e) {
      debugPrint('[AUTH ERROR] statusCode: ${e.statusCode}');
      debugPrint('[AUTH ERROR] message: ${e.message}');
      isSaving = false;
      notifyListeners();
      // If we have a context, use the global handler to redirect to WelcomeScreen
      if (context != null && context.mounted) {
        await SupabaseService.handleAuthError(e, context);
        return null;
      }
      saveError = kDebugMode
          ? 'Auth error [${e.statusCode}]: ${e.message}'
          : 'Could not save your profile. Please sign in again.';
      notifyListeners();
      return null;

    } on PostgrestException catch (e) {
      final msg = 'Supabase error [${e.code}]: ${e.message}\n'
          'Details: ${e.details}\nHint: ${e.hint}';
      debugPrint('[ERROR] $msg');
      isSaving = false;
      saveError = kDebugMode
          ? msg
          : 'Could not save your profile. Please try again.';
      notifyListeners();
      return null;

    } catch (e, stack) {
      debugPrint('[ERROR] saveToSupabase unexpected error: $e');
      debugPrint('[ERROR] Stack: $stack');
      isSaving = false;
      saveError = kDebugMode
          ? e.toString()
          : 'Could not save your profile. Please try again.';
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helper — builds a UserModel from current controller state.
  // ---------------------------------------------------------------------------
  UserModel _buildUserModel({
    required String id,
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
    double? proteinMultiplier,
  }) {
    return UserModel(
      id: id,
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
      proteinPreference: proteinPreference,
      liftingExperience: liftingExperience.isEmpty ? null : liftingExperience,
      proteinMultiplier: proteinMultiplier,
    );
  }

  // ---------------------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------------------
  void setName(String v)              { name = v; notifyListeners(); }
  void setSex(String v)               { biologicalSex = v; notifyListeners(); }
  void setDob(DateTime v)             { dateOfBirth = v; notifyListeners(); }
  void setHeight(double v)            { heightCm = v; notifyListeners(); }
  void setWeight(double v)            { weightKg = v; notifyListeners(); }
  void setGoal(String v) {
    goal = v;
    weeklyPacePercent = v == 'gain' ? 0.25 : 0.75;
    if (v == 'maintain') targetWeightKg = null;
    notifyListeners();
  }
  void setTargetWeight(double v)      { targetWeightKg = v; notifyListeners(); }
  void setActivityLevel(String v)     { activityLevel = v; notifyListeners(); }
  void setBodyFatRange(String? v)     { bodyFatRange = v; bodyFatSkipped = false; notifyListeners(); }
  void skipBodyFat()                  { bodyFatRange = null; bodyFatSkipped = true; notifyListeners(); }
  void setProteinPreference(String v) { proteinPreference = v; notifyListeners(); }
  void setLifeSituation(String v)     { lifeSituation = v; notifyListeners(); }
  void setRegion(String v)            { region = v; notifyListeners(); }
  void setLiftingExperience(String v) { liftingExperience = v; notifyListeners(); }
  void setPacePercent(double v)       { weeklyPacePercent = v; notifyListeners(); }
}
