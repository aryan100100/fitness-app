// [HEALTH APP] — Dashboard Provider
// ChangeNotifier that holds all today's dashboard data.
// Exposes refresh() and deleteFoodLog() for UI layer.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/dashboard_summary.dart';
import '../../models/food_log_model.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auto_adjustment_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/low_motivation_service.dart';
import '../../models/user_model.dart';
import '../../models/streak_model.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service = DashboardService.instance;

  DashboardSummary? _summary;
  Map<String, List<FoodLogModel>> _mealLogs = {};
  StreakModel? _streakModel;
  List<DayStatus> _last7Days = [];
  LowMotivationFlag _clinicalFlag = LowMotivationFlag.none;
  bool _hideStreakCounter = false;

  bool _isLoading = false;
  String? _error;

  DashboardSummary? get summary => _summary;
  Map<String, List<FoodLogModel>> get mealLogs => _mealLogs;
  StreakModel? get streakModel => _streakModel;
  List<DayStatus> get last7Days => _last7Days;
  LowMotivationFlag get clinicalFlag => _clinicalFlag;
  bool get hideStreakCounter => _hideStreakCounter;
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

      // OPTIMISTIC/OFFLINE LOAD
      var prefs = await SharedPreferences.getInstance();
      
      // Load summary
      final cachedSummaryStr = prefs.getString('cache_summary_$today');
      if (cachedSummaryStr != null) {
        try {
          _summary = DashboardSummary.fromJson(jsonDecode(cachedSummaryStr));
        } catch (_) {}
      }

      // Load meal logs
      final cachedLogsStr = prefs.getString('cache_logs_$today');
      if (cachedLogsStr != null) {
        try {
          final decoded = jsonDecode(cachedLogsStr) as Map<String, dynamic>;
          _mealLogs = decoded.map((key, value) {
            final list = (value as List).map((e) => FoodLogModel.fromJson(e)).toList();
            return MapEntry(key, list);
          });
        } catch (_) {}
      }

      if (_summary != null || _mealLogs.isNotEmpty) {
        notifyListeners(); // show cached UI instantly
      }

      // Fire all data loads in parallel
      final results = await Future.wait([
        _service.getTodaysTotals(userId, today),
        _service.getUserTargets(userId),
        _service.getTodayOverride(userId, today),
        StreakService.instance.getStreak(userId),
        StreakService.instance.getLast7Days(userId),
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
        LowMotivationService.instance.checkClinicalFlag(user),
        Supabase.instance.client.from('users').select('hide_streak_counter').eq('id', userId).single(),
      ]);

      final totals   = results[0] as Map<String, double>;
      final targets  = results[1] as Map<String, double>;
      final overrideType = results[2] as String?;
      _streakModel   = results[3] as StreakModel;
      _last7Days     = results[4] as List<DayStatus>;
      final weekly   = results[5] as Map<String, dynamic>;
      final confMap  = results[10] as Map<String, dynamic>;
      _clinicalFlag  = results[11] as LowMotivationFlag;
      final userRow  = results[12] as Map<String, dynamic>;
      _hideStreakCounter = userRow['hide_streak_counter'] == true;

      _mealLogs = {
        'breakfast': results[6] as List<FoodLogModel>,
        'lunch':     results[7] as List<FoodLogModel>,
        'dinner':    results[8] as List<FoodLogModel>,
        'snack':     results[9] as List<FoodLogModel>,
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
        currentStreak:  _streakModel!.currentStreak,
        weeklyCaloriesLogged: (weekly['weeklyCaloriesLogged'] as double),
        weeklyCaloriesTarget: (weekly['weeklyCaloriesTarget'] as double),
        weeklyDaysLogged:     (weekly['weeklyDaysLogged'] as int),
        tdeeConfidence:       confMap['confidence'] as TDEEConfidence,
        daysLoggedForCalibration: confMap['daysLogged'] as int,
        userName: user.name,
        bmi: bmi,
        goal: user.goal,
        isMinimumViableDay: overrideType == 'minimum_viable_day',
      );

      // SAVE CACHE
      prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_summary_$today', jsonEncode(_summary!.toJson()));
      
      final logsJson = _mealLogs.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_logs_$today', jsonEncode(logsJson));

      // Update streak silently after refresh (from person-b/fitness branch)
      // Removed because updateStreak was removed from DashboardService and moved to StreakService
      // Streak update has been decoupled from page load to food log save event (from person-a/nutrition branch).
    } catch (e) {
      // IF WE ALREADY HAVE CACHE, DON'T SHOW ERROR
      if (_summary == null) {
        _error = 'Could not load your data. Pull down to try again.';
      } else {
        _error = 'Offline. Showing cached data.';
      }
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
        isMinimumViableDay: _summary!.isMinimumViableDay,
      );
    }
    
    // SAVE CACHE AFTER DELETE
    final today = _todayStr();
    final prefs = await SharedPreferences.getInstance();
    if (_summary != null) {
      await prefs.setString('cache_summary_$today', jsonEncode(_summary!.toJson()));
    }
    final logsJson = _mealLogs.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()));
    await prefs.setString('cache_logs_$today', jsonEncode(logsJson));

    notifyListeners();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
