// [HEALTH APP] — Low Motivation Service (Feature 8)
// Handles option tracking, intervention flags, and applying day overrides.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

enum LowMotivationFlag { none, mild, strong, clinical }

class LowMotivationService {
  LowMotivationService._internal();
  static final instance = LowMotivationService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Check Intervention Flags
  // Mild: >3 uses in 7 days
  // Strong: >8 uses in 14 days OR 7 consecutive
  // ---------------------------------------------------------------------------
  Future<LowMotivationFlag> checkFlags(String userId) async {
    try {
      final now = DateTime.now();
      final fourteenDaysAgo = now.subtract(const Duration(days: 14)).toIso8601String();

      final response = await _client
          .from('low_motivation_logs')
          .select('used_at')
          .eq('user_id', userId)
          .gte('used_at', fourteenDaysAgo)
          .order('used_at', ascending: false);

      final logs = response as List;
      if (logs.isEmpty) return LowMotivationFlag.none;

      final dates = logs.map((l) {
        final dt = DateTime.parse(l['used_at'] as String);
        return _dateStr(dt);
      }).toSet().toList(); // Unique days

      // Strong Flag: >8 uses in 14 days
      if (dates.length > 8) return LowMotivationFlag.strong;

      // Strong Flag: 7 consecutive
      if (dates.length >= 7) {
        bool isConsecutive = true;
        for (int i = 0; i < 7; i++) {
          final expected = _dateStr(now.subtract(Duration(days: i)));
          if (dates[i] != expected) {
            isConsecutive = false;
            break;
          }
        }
        if (isConsecutive) return LowMotivationFlag.strong;
      }

      // Mild Flag: >3 uses in 7 days
      final sevenDaysAgoStr = _dateStr(now.subtract(const Duration(days: 7)));
      int last7Count = 0;
      for (final dStr in dates) {
        if (dStr.compareTo(sevenDaysAgoStr) >= 0) {
          last7Count++;
        }
      }
      if (last7Count > 3) return LowMotivationFlag.mild;

      return LowMotivationFlag.none;
    } catch (e) {
      debugPrint('[LOW_MOTIVATION] checkFlags error: $e');
      return LowMotivationFlag.none;
    }
  }

  // ---------------------------------------------------------------------------
  // Check Clinical Flag (Checked on Dashboard load)
  // True if Low Motivation > 3 AND Emergency Button > 3 in last 7 days
  // ---------------------------------------------------------------------------
  Future<LowMotivationFlag> checkClinicalFlag(UserModel user) async {
    try {
      final userId = user.id ?? '';
      if (userId.isEmpty) return LowMotivationFlag.none;

      // Check if already shown in the last 7 days
      if (user.lastClinicalFlagShown != null) {
        try {
          final lastShown = DateTime.parse(user.lastClinicalFlagShown!);
          if (DateTime.now().difference(lastShown).inDays < 7) {
            return LowMotivationFlag.none;
          }
        } catch (_) {}
      }

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

      // Check Low Motivation Logs
      final lmRes = await _client
          .from('low_motivation_logs')
          .select('id')
          .eq('user_id', userId)
          .gte('used_at', sevenDaysAgo);
      
      if ((lmRes as List).length <= 3) return LowMotivationFlag.none;

      // Check Emergency Button Logs
      final ebRes = await _client
          .from('emergency_button_logs')
          .select('id')
          .eq('user_id', userId)
          .gte('used_at', sevenDaysAgo);

      if ((ebRes as List).length <= 3) return LowMotivationFlag.none;

      return LowMotivationFlag.clinical;
    } catch (e) {
      debugPrint('[LOW_MOTIVATION] checkClinicalFlag error: $e');
      return LowMotivationFlag.none;
    }
  }

  Future<void> markClinicalFlagShown(String userId) async {
    try {
      await _client.from('users').update({
        'last_clinical_flag_shown': _dateStr(DateTime.now()),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[LOW_MOTIVATION] markClinicalFlagShown error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Check Maintenance Day Safety Limits
  // Max 3 consecutive days, max 8 days in 30 days
  // ---------------------------------------------------------------------------
  Future<bool> canUseMaintenanceDay(String userId) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30)).toIso8601String();

      final response = await _client
          .from('low_motivation_logs')
          .select('used_at')
          .eq('user_id', userId)
          .eq('option_chosen', 'Option B')
          .gte('used_at', thirtyDaysAgo)
          .order('used_at', ascending: false);

      final logs = response as List;
      if (logs.isEmpty) return true;

      final dates = logs.map((l) {
        final dt = DateTime.parse(l['used_at'] as String);
        return _dateStr(dt);
      }).toSet().toList();

      // Rule 1: Max 8 days per 30 days
      if (dates.length >= 8) return false;

      // Rule 2: Max 3 consecutive days
      if (dates.length >= 3) {
        bool isConsecutive = true;
        for (int i = 0; i < 3; i++) {
          final expected = _dateStr(now.subtract(Duration(days: i)));
          if (dates[i] != expected) {
            isConsecutive = false;
            break;
          }
        }
        if (isConsecutive) return false;
      }
      return true;
    } catch (e) {
      debugPrint('[LOW_MOTIVATION] canUseMaintenanceDay error: $e');
      return false; // Fail safe
    }
  }

  // ---------------------------------------------------------------------------
  // Log usage & Option Selection
  // ---------------------------------------------------------------------------
  Future<void> logUsage(String userId, String option) async {
    try {
      await _client.from('low_motivation_logs').insert({
        'user_id': userId,
        'option_chosen': option,
        'used_at': DateTime.now().toIso8601String(),
      });

      // Update user counts
      final userRes = await _client
          .from('users')
          .select('low_motivation_count')
          .eq('id', userId)
          .single();
      
      final currentCount = (userRes['low_motivation_count'] as int?) ?? 0;

      await _client.from('users').update({
        'low_motivation_count': currentCount + 1,
        'last_low_motivation_use': DateTime.now().toIso8601String(),
      }).eq('id', userId);

    } catch (e) {
      debugPrint('[LOW_MOTIVATION] logUsage error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Apply Option A: Minimum Viable Day
  // Reduces behavioural demand. Uses day_overrides table.
  // ---------------------------------------------------------------------------
  Future<void> applyMinimumViableDay(UserModel user) async {
    final userId = user.id ?? '';
    final todayStr = _dateStr(DateTime.now());

    try {
      await _client.from('day_overrides').upsert({
        'user_id': userId,
        'override_date': todayStr,
        'override_type': 'minimum_viable_day',
      }, onConflict: 'user_id, override_date');
      
      await logUsage(userId, 'Option A');
    } catch (e) {
      debugPrint('[LOW_MOTIVATION] applyOptionA error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Apply Option B: Maintenance Day
  // Eat at TDEE. Uses Feature 6 override system OR day overrides
  // ---------------------------------------------------------------------------
  Future<void> applyMaintenanceDay(UserModel user) async {
    final userId = user.id ?? '';
    final todayStr = _dateStr(DateTime.now());

    try {
      await _client.from('day_overrides').upsert({
        'user_id': userId,
        'override_date': todayStr,
        'override_type': 'maintenance_day',
      }, onConflict: 'user_id, override_date');

      // Also use the daily_targets override system for immediate target swap 
      // where DashboardService defaults to picking it up if we don't handle it manually
      await _client.from('daily_targets').upsert({
        'user_id': userId,
        'date': todayStr,
        'target_calories': user.tdee,
        'target_protein_g': user.proteinG,
        // Calculate remaining cals for Carbs/Fat ratio
        'target_carbs_g': ((user.tdee - (user.proteinG * 4)) * 0.5) / 4,
        'target_fat_g': ((user.tdee - (user.proteinG * 4)) * 0.5) / 9,
        'target_fibre_g': 25,
      }, onConflict: 'user_id, date');

      await logUsage(userId, 'Option B');
    } catch (e) {
      debugPrint('[LOW_MOTIVATION] applyOptionB error: $e');
    }
  }
}
