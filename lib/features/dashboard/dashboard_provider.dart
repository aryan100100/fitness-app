// [HEALTH APP] — Dashboard Provider
// ChangeNotifier that holds all today's dashboard data.
// Exposes refresh() and deleteFoodLog() for UI layer.

import 'package:flutter/foundation.dart';
import '../../models/dashboard_summary.dart';
import '../../models/food_log_model.dart';
import '../../models/user_model.dart';
import '../../core/services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service = DashboardService.instance;

  DashboardSummary? _summary;
  Map<String, List<FoodLogModel>> _mealLogs = {};

  bool _isLoading = false;
  String? _error;

  // Getters
  DashboardSummary? get summary => _summary;
  Map<String, List<FoodLogModel>> get mealLogs => _mealLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<FoodLogModel> logsForMeal(String mealType) =>
      _mealLogs[mealType] ?? [];

  // ---------------------------------------------------------------------------
  // Full refresh — called on screen init and after food is added/deleted
  // ---------------------------------------------------------------------------
  Future<void> refresh(UserModel user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = user.id ?? '';
      final today = _todayStr();

      // Fire all data loads in parallel
      final results = await Future.wait([
        _service.getTodaysTotals(userId, today),
        _service.getUserTargets(userId),
        _service.getCurrentStreak(userId),
        _service.getWeeklySummary(userId, user.targetCalories),
        _service.getMealLogs(userId, today, 'breakfast'),
        _service.getMealLogs(userId, today, 'lunch'),
        _service.getMealLogs(userId, today, 'dinner'),
        _service.getMealLogs(userId, today, 'snack'),
        _service.getTDEEConfidenceStatus(
          userId,
          user.goalStartDate != null
              ? DateTime.tryParse(user.goalStartDate!)
              : null,
        ),
      ]);

      final totals  = results[0] as Map<String, double>;
      final targets = results[1] as Map<String, double>;
      final streak  = results[2] as int;
      final weekly  = results[3] as Map<String, dynamic>;
      final confMap = results[8] as Map<String, dynamic>;

      _mealLogs = {
        'breakfast': results[4] as List<FoodLogModel>,
        'lunch':     results[5] as List<FoodLogModel>,
        'dinner':    results[6] as List<FoodLogModel>,
        'snack':     results[7] as List<FoodLogModel>,
      };

      final heightM = user.heightCm / 100;
      final bmi = user.weightKg / (heightM * heightM);

      _summary = DashboardSummary(
        totalCalories: totals['calories']!,
        totalProtein:  totals['protein']!,
        totalCarbs:    totals['carbs']!,
        totalFat:      totals['fat']!,
        totalFibre:    totals['fibre']!,
        targetCalories: targets['targetCalories']!,
        targetProtein:  targets['targetProtein']!,
        targetCarbs:    targets['targetCarbs']!,
        targetFat:      targets['targetFat']!,
        targetFibre:    targets['targetFibre']!,
        currentStreak:  streak,
        weeklyCaloriesLogged: (weekly['weeklyCaloriesLogged'] as double),
        weeklyCaloriesTarget: (weekly['weeklyCaloriesTarget'] as double),
        weeklyDaysLogged:     (weekly['weeklyDaysLogged'] as int),
        tdeeConfidence:       confMap['confidence'] as TDEEConfidence,
        daysLoggedForCalibration: confMap['daysLogged'] as int,
        userName: user.name,
        bmi: bmi,
        goal: user.goal,
      );

      // Update streak silently after refresh
      _service.updateStreak(userId).ignore();
    } catch (e) {
      _error = 'Could not load your data. Pull down to try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a single food log entry — updates UI instantly without full reload
  // ---------------------------------------------------------------------------
  Future<void> deleteFoodLog(String foodLogId, String mealType) async {
    final success = await _service.deleteFoodLog(foodLogId);
    if (!success) return;

    _mealLogs[mealType]?.removeWhere((e) => e.id == foodLogId);

    // Recompute today's totals from in-memory lists
    double cal = 0, prot = 0, carbs = 0, fat = 0, fibre = 0;
    for (final logs in _mealLogs.values) {
      for (final log in logs) {
        cal   += log.calories;
        prot  += log.proteinG;
        carbs += log.carbsG;
        fat   += log.fatG;
        fibre += log.fibreG;
      }
    }

    if (_summary != null) {
      _summary = DashboardSummary(
        totalCalories: cal,
        totalProtein:  prot,
        totalCarbs:    carbs,
        totalFat:      fat,
        totalFibre:    fibre,
        targetCalories: _summary!.targetCalories,
        targetProtein:  _summary!.targetProtein,
        targetCarbs:    _summary!.targetCarbs,
        targetFat:      _summary!.targetFat,
        targetFibre:    _summary!.targetFibre,
        currentStreak:  _summary!.currentStreak,
        weeklyCaloriesLogged: _summary!.weeklyCaloriesLogged,
        weeklyCaloriesTarget: _summary!.weeklyCaloriesTarget,
        weeklyDaysLogged:     _summary!.weeklyDaysLogged,
        tdeeConfidence:       _summary!.tdeeConfidence,
        daysLoggedForCalibration: _summary!.daysLoggedForCalibration,
        userName: _summary!.userName,
        bmi: _summary!.bmi,
        goal: _summary!.goal,
      );
    }
    notifyListeners();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
