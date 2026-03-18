// [HEALTH APP] — Profile Screen (Feature 9 updated)
// Profile tab with streak settings, Progress Photos section, and sign out.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/progress_photo_service.dart';
import '../../models/user_model.dart';
import '../onboarding/onboarding_screen.dart';
import '../progress_photos/progress_photo_optin_card.dart';
import '../progress_photos/progress_photos_screen.dart';

class DevProfileScreen extends StatefulWidget {
  final UserModel? user;
  const DevProfileScreen({super.key, this.user});

  @override
  State<DevProfileScreen> createState() => _DevProfileScreenState();
}

class _DevProfileScreenState extends State<DevProfileScreen> {
  bool _isSigningOut = false;
  bool _hideStreakCounter = false;
  bool _progressPhotosEnabled = false;
  bool _reminderEnabled = false;
  int _reminderIntervalDays = 14;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final res = await Supabase.instance.client
          .from('users')
          .select(
              'hide_streak_counter, progress_photos_enabled, progress_photo_reminder_enabled, progress_photo_reminder_interval_days')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _hideStreakCounter = res['hide_streak_counter'] == true;
          _progressPhotosEnabled = res['progress_photos_enabled'] == true;
          _reminderEnabled = res['progress_photo_reminder_enabled'] == true;
          _reminderIntervalDays =
              (res['progress_photo_reminder_interval_days'] as num?)?.toInt() ??
                  14;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PROFILE] Error loading settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHideStreak(bool value) async {
    setState(() => _hideStreakCounter = value);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('users')
          .update({'hide_streak_counter': value}).eq('id', userId);
    } catch (e) {
      debugPrint('[PROFILE] Error updating hide_streak_counter: $e');
      if (mounted) setState(() => _hideStreakCounter = !value);
    }
  }

  Future<void> _toggleProgressPhotos(bool value) async {
    setState(() => _progressPhotosEnabled = value);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('users')
          .update({'progress_photos_enabled': value}).eq('id', userId);
    } catch (e) {
      debugPrint('[PROFILE] Error updating progress_photos_enabled: $e');
      if (mounted) setState(() => _progressPhotosEnabled = !value);
    }
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _reminderEnabled = value);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('users').update(
          {'progress_photo_reminder_enabled': value}).eq('id', userId);
    } catch (e) {
      debugPrint('[PROFILE] Error updating reminder: $e');
      if (mounted) setState(() => _reminderEnabled = !value);
    }
  }

  Future<void> _updateReminderInterval(int days) async {
    setState(() => _reminderIntervalDays = days);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('users').update(
          {'progress_photo_reminder_interval_days': days}).eq('id', userId);
    } catch (e) {
      debugPrint('[PROFILE] Error updating reminder interval: $e');
    }
  }

  Future<void> _confirmDeleteAllPhotos() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Count photos first
    final photos =
        await ProgressPhotoService.instance.getAllPhotos(userId);
    final count = photos.length;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Delete all progress photos?', style: AppTextStyles.body),
        content: Text(
          'This will permanently delete all $count of your progress photos. This cannot be undone.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.captionAccent),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete all photos',
                style: AppTextStyles.captionAccent
                    .copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ProgressPhotoService.instance.deleteAllPhotos(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All photos deleted ✅',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete photos. Try again.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _navigateToProgressPhotos() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final user = widget.user ??
        UserModel(
          id: userId,
          name: '',
          age: 0,
          biologicalSex: 'male',
          heightCm: 0,
          weightKg: 0,
          goal: 'maintain',
          activityLevel: 'sedentary',
          lifeSituation: 'other',
          tdee: 0,
          targetCalories: 0,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
        );

    if (_progressPhotosEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgressPhotosScreen(user: user),
        ),
      );
    } else {
      // Check if permanently skipped
      final prefs = await SharedPreferences.getInstance();
      final skipped = prefs.getBool('progress_photo_skip_$userId') ?? false;
      if (skipped && !_progressPhotosEnabled) {
        // Re-enable via toggle in settings, not via opt-in flow
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgressPhotoOptInCard(user: user),
        ),
      ).then((_) => _loadSettings());
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLowPressure = widget.user?.lowPressureMode ?? false;
    // Show progress photos only if: not low pressure mode, OR already enabled
    final showProgressPhotos = !isLowPressure || _progressPhotosEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headingMedium),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Streak settings ─────────────────────────────────────────
                Text('Streaks', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text('Hide streak counter', style: AppTextStyles.body),
                  subtitle: Text(
                    'Removes the streak tracker from your dashboard if it causes stress.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.secondaryText),
                  ),
                  value: _hideStreakCounter,
                  onChanged: _toggleHideStreak,
                  activeThumbColor: AppColors.primaryAccent,
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(color: AppColors.divider, height: 32),

                // ── Progress Photos section ──────────────────────────────────
                if (showProgressPhotos) ...[
                  Row(
                    children: [
                      Text('Progress Photos 📸',
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (_progressPhotosEnabled)
                        TextButton(
                          onPressed: _navigateToProgressPhotos,
                          child: Text('Open',
                              style: AppTextStyles.captionAccent
                                  .copyWith(fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (!_progressPhotosEnabled)
                    GestureDetector(
                      onTap: _navigateToProgressPhotos,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_camera_outlined,
                                color: AppColors.secondaryText, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Track your progress visually',
                                  style: AppTextStyles.body),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.secondaryText),
                          ],
                        ),
                      ),
                    ),

                  if (_progressPhotosEnabled) ...[
                    SwitchListTile(
                      title:
                          Text('Progress photos', style: AppTextStyles.body),
                      subtitle: Text(
                          'Hides the feature but keeps your existing photos.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.secondaryText)),
                      value: _progressPhotosEnabled,
                      onChanged: _toggleProgressPhotos,
                      activeThumbColor: AppColors.primaryAccent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: Text('Photo reminders', style: AppTextStyles.body),
                      subtitle: Text('Remind me to take progress photos',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.secondaryText)),
                      value: _reminderEnabled,
                      onChanged: _toggleReminder,
                      activeThumbColor: AppColors.primaryAccent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_reminderEnabled) ...[
                      const SizedBox(height: 4),
                      Text('Reminder frequency',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.secondaryText)),
                      const SizedBox(height: 8),
                      Row(
                        children: [14, 21, 28].map((days) {
                          final label = days == 14
                              ? 'Every 2 weeks'
                              : days == 21
                                  ? 'Every 3 weeks'
                                  : 'Every 4 weeks';
                          final isSelected = _reminderIntervalDays == days;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _updateReminderInterval(days),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryAccent
                                      : AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.black
                                        : AppColors.secondaryText,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _confirmDeleteAllPhotos,
                      child: Text('Delete all progress photos',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.destructive)),
                    ),
                  ],

                  const Divider(color: AppColors.divider, height: 32),
                ],

                // ── Sign out ─────────────────────────────────────────────────
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: _isSigningOut ? null : _signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5252),
                        side: const BorderSide(
                            color: Color(0xFFFF5252), width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSigningOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF5252)),
                              ),
                            )
                          : const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        _isSigningOut ? 'Signing out…' : 'Sign Out',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dev mode — tap to clear session and restart onboarding',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
