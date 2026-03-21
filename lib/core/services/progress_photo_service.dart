// [HEALTH APP] — Progress Photo Service (Feature 9)
// Handles all Supabase Storage and DB operations for progress photos.
// All photos use signed URLs (1hr expiry) — NEVER public URLs.
// No AI analysis of any kind — photos are stored and shown, nothing more.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/progress_photo_model.dart';

class ProgressPhotoService {
  ProgressPhotoService._internal();
  static final instance = ProgressPhotoService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  static const _bucket = 'progress-photos';

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Upload photo to Supabase Storage and insert row in progress_photos.
  // Storage path: {userId}/{date}/{angle}.jpg
  // ---------------------------------------------------------------------------
  Future<void> savePhoto(
      String userId, DateTime date, String angle, File imageFile) async {
    try {
      final dateStr = _dateStr(date);
      final storagePath = '$userId/$dateStr/$angle.jpg';

      // Upload — upsert if same date+angle already exists
      await _client.storage.from(_bucket).upload(
            storagePath,
            imageFile,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Upsert DB row
      await _client.from('progress_photos').upsert({
        'user_id': userId,
        'photo_date': dateStr,
        'angle': angle,
        'storage_path': storagePath,
      }, onConflict: 'user_id, photo_date, angle');
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] savePhoto error: $e');
      rethrow; // Bubble up so UI can show error snackbar
    }
  }

  // ---------------------------------------------------------------------------
  // Get all photo records for a user, sorted by date descending.
  // ---------------------------------------------------------------------------
  Future<List<ProgressPhoto>> getAllPhotos(String userId) async {
    try {
      final res = await _client
          .from('progress_photos')
          .select()
          .eq('user_id', userId)
          .order('photo_date', ascending: false)
          .order('angle', ascending: true);

      return (res as List).map((e) => ProgressPhoto.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] getAllPhotos error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Get signed URL for a single photo (1 hour expiry).
  // ---------------------------------------------------------------------------
  Future<String?> getSignedUrl(String storagePath) async {
    try {
      final signedUrl = await _client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, 3600);
      return signedUrl;
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] getSignedUrl error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a single photo — removes from Storage AND progress_photos table.
  // ---------------------------------------------------------------------------
  Future<void> deletePhoto(
      String userId, String photoId, String storagePath) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
      await _client.from('progress_photos').delete().eq('id', photoId);
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] deletePhoto error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete ALL photos for a user.
  // Lists all files under {userId}/, deletes from Storage, then purges DB rows.
  // ---------------------------------------------------------------------------
  Future<void> deleteAllPhotos(String userId) async {
    try {
      // List all files under user's folder
      final files = await _client.storage.from(_bucket).list(path: userId);
      if (files.isNotEmpty) {
        // Storage returns flat objects — we need to traverse date subfolders
        // Use a recursive approach by listing all date folders first
        final List<String> allPaths = [];
        for (final folder in files) {
          try {
            final subFiles = await _client.storage
                .from(_bucket)
                .list(path: '$userId/${folder.name}');
            for (final f in subFiles) {
              allPaths.add('$userId/${folder.name}/${f.name}');
            }
          } catch (_) {}
        }
        if (allPaths.isNotEmpty) {
          await _client.storage.from(_bucket).remove(allPaths);
        }
      }
      // Delete all DB rows
      await _client.from('progress_photos').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] deleteAllPhotos error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Get photos for a specific date.
  // ---------------------------------------------------------------------------
  Future<List<ProgressPhoto>> getPhotosForDate(
      String userId, DateTime date) async {
    try {
      final dateStr = _dateStr(date);
      final res = await _client
          .from('progress_photos')
          .select()
          .eq('user_id', userId)
          .eq('photo_date', dateStr);

      return (res as List).map((e) => ProgressPhoto.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] getPhotosForDate error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Get all unique dates that have at least one photo, sorted newest first.
  // ---------------------------------------------------------------------------
  Future<List<DateTime>> getPhotoDatesList(String userId) async {
    try {
      final res = await _client
          .from('progress_photos')
          .select('photo_date')
          .eq('user_id', userId)
          .order('photo_date', ascending: false);

      final dates = (res as List)
          .map((e) => DateTime.parse(e['photo_date'] as String))
          .toSet()
          .toList();
      dates.sort((a, b) => b.compareTo(a));
      return dates;
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] getPhotoDatesList error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Check if user has opened comparison screen too frequently:
  // - More than 3 times today, OR
  // - Daily for 5 consecutive days
  // ---------------------------------------------------------------------------
  Future<bool> shouldShowFrequencyWarning(String userId) async {
    try {
      final res = await _client
          .from('users')
          .select('progress_photos_comparison_streak, last_comparison_date')
          .eq('id', userId)
          .single();

      final streak = (res['progress_photos_comparison_streak'] as num?)?.toInt() ?? 0;
      final lastDateStr = res['last_comparison_date'] as String?;

      if (lastDateStr == null) return false;

      final today = DateTime.now();
      final todayStr = _dateStr(today);

      // More than 3 views today
      if (lastDateStr == todayStr && streak > 3) return true;

      // Daily for 5+ consecutive days
      if (streak >= 5) return true;

      return false;
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] shouldShowFrequencyWarning error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Track comparison screen open — updates streak and last_comparison_date.
  // ---------------------------------------------------------------------------
  Future<void> logComparisonView(String userId) async {
    try {
      final res = await _client
          .from('users')
          .select('progress_photos_comparison_streak, last_comparison_date')
          .eq('id', userId)
          .single();

      final todayStr = _dateStr(DateTime.now());
      final lastDateStr = res['last_comparison_date'] as String?;
      int streak = (res['progress_photos_comparison_streak'] as num?)?.toInt() ?? 0;

      if (lastDateStr == null) {
        streak = 1;
      } else if (lastDateStr == todayStr) {
        // Same day — increment counter
        streak += 1;
      } else {
        final lastDate = DateTime.parse(lastDateStr);
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff == 1) {
          // Consecutive day — but reset counter to 1 for today with running streak
          streak = (streak >= 3) ? streak + 1 : 1;
        } else {
          // Gap — reset
          streak = 1;
        }
      }

      await _client.from('users').update({
        'progress_photos_comparison_streak': streak,
        'last_comparison_date': todayStr,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] logComparisonView error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Check and trigger in-app reminder if due.
  // Returns true if a reminder should be shown.
  // ---------------------------------------------------------------------------
  Future<bool> shouldShowReminder(
      bool reminderEnabled, int intervalDays, String? lastReminderDate) {
    if (!reminderEnabled) return Future.value(false);
    if (lastReminderDate == null) return Future.value(true);
    final last = DateTime.tryParse(lastReminderDate);
    if (last == null) return Future.value(true);
    final daysSince = DateTime.now().difference(last).inDays;
    return Future.value(daysSince >= intervalDays);
  }

  // ---------------------------------------------------------------------------
  // Mark the reminder as shown today.
  // ---------------------------------------------------------------------------
  Future<void> markReminderShown(String userId) async {
    try {
      await _client.from('users').update({
        'last_progress_photo_reminder': _dateStr(DateTime.now()),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[PROGRESS_PHOTO] markReminderShown error: $e');
    }
  }
}
