// [HEALTH APP] — Streak Service (Feature 8)
// Handles calculating and updating streaks based strictly on logging behaviour.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/streak_model.dart';

enum DayStatus { logged, grace, unlogged, future }

class StreakService {
  StreakService._internal();
  static final instance = StreakService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Get current streak
  // ---------------------------------------------------------------------------
  Future<StreakModel> getStreak(String userId) async {
    try {
      final res = await _client
          .from('streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
        return StreakModel.fromJson(res);
      }
    } catch (e) {
      debugPrint('[STREAK] getStreak error: $e');
    }
    // Return empty state if none exists or error
    return StreakModel(
      userId: userId,
      currentStreak: 0,
      graceDaysUsedThisWindow: 0,
      longestStreak: 0,
      streakHidden: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Update Streak — Called every time a food log is saved
  // ---------------------------------------------------------------------------
  Future<void> updateStreak(String userId, DateTime today) async {
    try {
      final todayStr = _dateStr(today);
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = _dateStr(yesterday);
      final twoDaysAgoStr = _dateStr(today.subtract(const Duration(days: 2)));

      final current = await getStreak(userId);

      // If already logged today, do nothing (streak already counted this day).
      if (current.lastLogDate == todayStr) return;

      int newStreak = 1;
      int newGraceDays = current.graceDaysUsedThisWindow;
      String? newLastGraceDate = current.lastGraceDay;
      String? lastLog = current.lastLogDate;

      // Reset grace day window if last grace was > 7 days ago
      if (current.lastGraceDay != null) {
        final lastGraceDt = DateTime.parse(current.lastGraceDay!);
        if (today.difference(lastGraceDt).inDays > 7) {
          newGraceDays = 0;
        }
      }

      if (lastLog == yesterdayStr) {
        // Perfect consecutive logging
        newStreak = current.currentStreak + 1;
      } else if (lastLog == twoDaysAgoStr) {
        // Skipped yesterday natively. Check if we have a grace day available.
        if (newGraceDays == 0) {
          // Consume grace day for yesterday
          newStreak = current.currentStreak + 2; // +1 for yesterday (grace), +1 for today
          newGraceDays = 1;
          newLastGraceDate = yesterdayStr;
        } else {
          // Grace day already used in this rolling window — streak resets
          newStreak = 1;
        }
      } else if (lastLog != null) {
        // Gap is larger than 2 days — definitely resets.
        newStreak = 1;
      }

      final newLongest =
          newStreak > current.longestStreak ? newStreak : current.longestStreak;

      await _client.from('streaks').upsert({
        'user_id': userId,
        'current_streak': newStreak,
        'last_log_date': todayStr,
        'grace_days_used_this_window': newGraceDays,
        'last_grace_day': newLastGraceDate,
        'longest_streak': newLongest,
        'streak_hidden': current.streakHidden,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[STREAK] Updated: $newStreak streak');
    } catch (e) {
      debugPrint('[STREAK] updateStreak error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Milestones
  // ---------------------------------------------------------------------------
  bool shouldShowMilestone(int currentStreak) {
    const milestones = [3, 7, 14, 30, 60, 90];
    return milestones.contains(currentStreak);
  }

  // ---------------------------------------------------------------------------
  // Get last 7 days status for timeline dots
  // ---------------------------------------------------------------------------
  Future<List<DayStatus>> getLast7Days(String userId) async {
    try {
      final now = DateTime.now();
      final dates = List.generate(
          7, (i) => now.subtract(Duration(days: 6 - i)));

      final todayStr = _dateStr(now);
      final startStr = _dateStr(dates.first);

      // Query food_logs for distinct logging days in the last 7 days
      final logs = await _client
          .from('food_logs')
          .select('date')
          .eq('user_id', userId)
          .gte('date', startStr)
          .lte('date', todayStr);

      final loggedDatesStr = (logs as List)
          .map((e) => e['date'] as String)
          .toSet();

      final streak = await getStreak(userId);
      final List<DayStatus> statuses = [];

      for (var dt in dates) {
        final dStr = _dateStr(dt);
        
        if (dt.isAfter(now) || (dStr == todayStr && dt.day > now.day)) {
           // safety bounds (should not happen with this generation)
           statuses.add(DayStatus.future);
        } else if (loggedDatesStr.contains(dStr)) {
          statuses.add(DayStatus.logged);
        } else if (streak.lastGraceDay == dStr) {
          statuses.add(DayStatus.grace);
        } else {
          // Note: if user just hasn't logged today yet, it shows future or unlogged?
          // If it's today and not logged, we show an empty circle (future) so it doesn't look discouraging immediately.
          if (dStr == todayStr) {
            statuses.add(DayStatus.future);
          } else {
            statuses.add(DayStatus.unlogged);
          }
        }
      }

      return statuses;
    } catch (e) {
      debugPrint('[STREAK] getLast7Days error: $e');
      return List.filled(7, DayStatus.unlogged);
    }
  }
}
