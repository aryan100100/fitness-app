// [HEALTH APP] — Full Profile Screen (Feature 11)
// Single scrollable screen: hero card, week summary, goals, settings, wellbeing,
// app settings, logout. Parallel data loading with shimmer loading state.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/progress_photo_service.dart';
import '../../core/services/supabase_service.dart';
import '../../models/user_model.dart';
import '../dashboard/dashboard_provider.dart';

import '../onboarding/onboarding_screen.dart';
import '../progress_photos/progress_photos_screen.dart';
import '../progress_photos/progress_photo_optin_card.dart';
import 'edit_profile_screen.dart';
import 'recalculate_plan_screen.dart';
import 'widgets/data_privacy_screen.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_row.dart';
import 'widgets/settings_toggle_row.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  late UserModel _user;
  bool _isLoading = true;

  // Loaded data
  int _currentStreak = 0;
  double? _latestWeight;
  int _photoCount = 0;

  // This week: 7 slots — index 0 = Mon … 6 = Sun
  final List<_DayData> _weekData =
      List.generate(7, (_) => _DayData(calories: 0, target: 0, logged: false));
  int _todayIndex = 0; // 0=Mon…6=Sun

  // Settings toggles (local mirrors so toggles respond instantly)
  late bool _lowPressureMode;
  late bool _hideStreakCounter;
  late bool _progressPhotosEnabled;
  late bool _photoReminderEnabled;
  late int _photoReminderIntervalDays;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _lowPressureMode = _user.lowPressureMode;
    _hideStreakCounter = _user.hideStreakCounter;
    _progressPhotosEnabled = _user.progressPhotosEnabled;
    _photoReminderEnabled = _user.progressPhotoReminderEnabled;
    _photoReminderIntervalDays = _user.progressPhotoReminderIntervalDays;
    _loadAll();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    try {
      await Future.wait([
        _loadUserProfile(),
        _loadCurrentStreak(),
        _loadWeekSummary(),
        _loadLatestWeight(),
        _loadPhotoCount(),
      ]);
    } catch (e) {
      debugPrint('[PROFILE] load error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = _user.id ?? '';
      final res = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _user = UserModel.fromJson(res);
          _lowPressureMode = _user.lowPressureMode;
          _hideStreakCounter = _user.hideStreakCounter;
          _progressPhotosEnabled = _user.progressPhotosEnabled;
          _photoReminderEnabled = _user.progressPhotoReminderEnabled;
          _photoReminderIntervalDays = _user.progressPhotoReminderIntervalDays;
        });
      }
    } catch (e) {
      debugPrint('[PROFILE] _loadUserProfile error: $e');
    }
  }

  Future<void> _loadCurrentStreak() async {
    try {
      final userId = _user.id ?? '';
      final streak = await StreakService.instance.getStreak(userId);
      if (mounted) setState(() => _currentStreak = streak.currentStreak);
    } catch (e) {
      debugPrint('[PROFILE] _loadCurrentStreak error: $e');
    }
  }

  Future<void> _loadWeekSummary() async {
    try {
      final userId = _user.id ?? '';
      final now = DateTime.now();
      // ISO weekday: 1=Mon … 7=Sun → map to index 0–6
      _todayIndex = now.weekday - 1;

      final monday = now.subtract(Duration(days: _todayIndex));
      final mondayStr =
          '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final rows = await Supabase.instance.client
          .from('food_logs')
          .select('date, calories')
          .eq('user_id', userId)
          .gte('date', mondayStr)
          .lte('date', todayStr);

      // Aggregate by date
      final Map<String, double> calsByDate = {};
      for (final row in rows) {
        final d = row['date'] as String? ?? '';
        final c = (row['calories'] as num?)?.toDouble() ?? 0;
        calsByDate[d] = (calsByDate[d] ?? 0) + c;
      }

      final List<_DayData> data = List.generate(7, (_) => _DayData());
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final cals = calsByDate[dateStr] ?? 0;
        final isFuture = i > _todayIndex;
        data[i] = _DayData(
          calories: cals,
          target: _user.targetCalories,
          logged: !isFuture && cals > 0,
          isFuture: isFuture,
        );
      }

      if (mounted) setState(() => _weekData.setAll(0, data));
    } catch (e) {
      debugPrint('[PROFILE] _loadWeekSummary error: $e');
    }
  }

  Future<void> _loadLatestWeight() async {
    try {
      final userId = _user.id ?? '';
      final rows = await Supabase.instance.client
          .from('weight_logs')
          .select('weight_kg')
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(1);
      if (rows.isNotEmpty && mounted) {
        setState(() =>
            _latestWeight = (rows.first['weight_kg'] as num?)?.toDouble());
      }
    } catch (e) {
      debugPrint('[PROFILE] _loadLatestWeight error: $e');
    }
  }

  Future<void> _loadPhotoCount() async {
    try {
      final userId = _user.id ?? '';
      final photos = await ProgressPhotoService.instance.getAllPhotos(userId);
      if (mounted) setState(() => _photoCount = photos.length);
    } catch (e) {
      debugPrint('[PROFILE] _loadPhotoCount error: $e');
    }
  }

  // ── Toggle helpers ─────────────────────────────────────────────────────────
  Future<void> _toggleLowPressure(bool v) async {
    setState(() => _lowPressureMode = v);
    try {
      await SupabaseService.instance.updateUser({'low_pressure_mode': v});
      if (v && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Supportive mode on 💙 We\'ll keep things gentle.'),
          backgroundColor: Color(0xFF1A3A5C),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('[PROFILE] low pressure toggle error: $e');
      if (mounted) setState(() => _lowPressureMode = !v);
    }
  }

  Future<void> _toggleHideStreak(bool v) async {
    setState(() => _hideStreakCounter = v);
    try {
      await SupabaseService.instance.updateUser({'hide_streak_counter': v});
    } catch (e) {
      debugPrint('[PROFILE] hide streak toggle error: $e');
      if (mounted) setState(() => _hideStreakCounter = !v);
    }
  }

  Future<void> _togglePhotoReminder(bool v) async {
    setState(() => _photoReminderEnabled = v);
    try {
      await SupabaseService.instance
          .updateUser({'progress_photo_reminder_enabled': v});
    } catch (e) {
      debugPrint('[PROFILE] photo reminder toggle error: $e');
      if (mounted) setState(() => _photoReminderEnabled = !v);
    }
  }

  Future<void> _toggleWeightUnit() async {
    final newUnit = _user.weightUnit == 'kg' ? 'lbs' : 'kg';
    setState(() => _user = _user.copyWith(weightUnit: newUnit));
    try {
      await SupabaseService.instance.updateUser({'weight_unit': newUnit});
    } catch (e) {
      debugPrint('[PROFILE] weight unit toggle error: $e');
      if (mounted) {
        setState(() => _user = _user.copyWith(
            weightUnit: newUnit == 'kg' ? 'lbs' : 'kg'));
      }
    }
  }

  // ── Sheet pickers ──────────────────────────────────────────────────────────
  Future<void> _pickCheckinDay() async {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Weekly Check-in Day', style: AppTextStyles.headingMedium),
        children: List.generate(7, (i) {
          final isSelected = _user.checkinDay == i + 1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, i + 1),
            child: Row(children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_off,
                color: isSelected
                    ? AppColors.primaryAccent
                    : AppColors.secondaryText,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(days[i],
                  style: AppTextStyles.body.copyWith(
                    color: isSelected
                        ? AppColors.primaryAccent
                        : AppColors.primaryText,
                  )),
            ]),
          );
        }),
      ),
    );
    if (picked != null && picked != _user.checkinDay && mounted) {
      setState(() => _user = _user.copyWith(checkinDay: picked));
      try {
        await SupabaseService.instance.updateUser({'checkin_day': picked});
      } catch (e) {
        debugPrint('[PROFILE] checkin day error: $e');
      }
    }
  }

  Future<void> _pickProteinPreference() async {
    const options = ['comfortable', 'moderate', 'high'];
    const labels = ['Comfortable', 'Moderate', 'High'];
    const descriptions = [
      'Lower protein goals — easier to hit, less dietary restriction',
      'Balanced protein targets based on your body stats',
      'Higher protein to maximise muscle support and satiety',
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Protein preference', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ...List.generate(3, (i) {
              final selected = _user.proteinPreference == options[i];
              return GestureDetector(
                onTap: () => Navigator.pop(context, options[i]),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryAccent.withValues(alpha: 0.12)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected
                            ? AppColors.primaryAccent
                            : AppColors.divider),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labels[i],
                              style: AppTextStyles.body.copyWith(
                                color: selected
                                    ? AppColors.primaryAccent
                                    : AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Text(descriptions[i],
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.secondaryText,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryAccent, size: 18),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != _user.proteinPreference && mounted) {
      setState(() => _user = _user.copyWith(proteinPreference: picked));
      try {
        await SupabaseService.instance
            .updateUser({'protein_preference': picked});
      } catch (e) {
        debugPrint('[PROFILE] protein pref error: $e');
      }
    }
  }

  Future<void> _pickReminderInterval() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Photo reminder frequency', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ...[14, 21, 28].map((days) {
              final label = days == 14
                  ? 'Every 2 weeks'
                  : days == 21
                      ? 'Every 3 weeks'
                      : 'Every 4 weeks';
              final selected = _photoReminderIntervalDays == days;
              return ListTile(
                onTap: () => Navigator.pop(context, days),
                title: Text(label, style: AppTextStyles.body),
                trailing: selected
                    ? const Icon(Icons.check_circle,
                        color: AppColors.primaryAccent, size: 20)
                    : null,
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != _photoReminderIntervalDays && mounted) {
      setState(() => _photoReminderIntervalDays = picked);
      try {
        await SupabaseService.instance.updateUser(
            {'progress_photo_reminder_interval_days': picked});
      } catch (e) {
        debugPrint('[PROFILE] reminder interval error: $e');
      }
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  Future<void> _openEditProfile() async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
    );
    if (refreshed == true && mounted) {
      await _loadAll(); // re-fetches _user from Supabase
      // Immediately push the updated targets to the dashboard
      if (mounted) {
        context.read<DashboardProvider>().refresh(_user);
      }
    }
  }

  Future<void> _openRecalculate() async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => RecalculatePlanScreen(user: _user)),
    );
    if (refreshed == true && mounted) {
      await _loadAll(); // re-fetches _user from Supabase
      // Immediately push the updated targets to the dashboard
      if (mounted) {
        context.read<DashboardProvider>().refresh(_user);
      }
    }
  }

  Future<void> _openProgressPhotos() async {
    if (_progressPhotosEnabled) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProgressPhotosScreen(user: _user)),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProgressPhotoOptInCard(user: _user)),
      );
    }
    if (mounted) _loadAll();
  }

  void _openEmergencySheet() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Open the Dashboard tab and tap the amber Emergency button'),
      backgroundColor: AppColors.cardSurface,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _shareApp() {
    Share.share(
      "I've been using this app to track my nutrition — it's really good. Check it out!",
      subject: 'Health & Nutrition Tracker',
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Sign Out?', style: AppTextStyles.headingMedium),
        content: Text('Are you sure you want to log out?',
            style: AppTextStyles.bodySecondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.captionAccent
                    .copyWith(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log out',
                style: AppTextStyles.captionAccent
                    .copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  // ── Computed helpers ───────────────────────────────────────────────────────
  String get _goalEmoji {
    switch (_user.goal) {
      case 'lose': return 'Losing weight';
      case 'gain': return 'Gaining muscle';
      default: return 'Maintaining';
    }
  }

  String get _checkinDayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = (_user.checkinDay - 1).clamp(0, 6);
    return days[idx];
  }

  String get _proteinPrefLabel {
    switch (_user.proteinPreference) {
      case 'high': return 'High';
      case 'comfortable': return 'Comfortable';
      default: return 'Moderate';
    }
  }

  String _formatWeight(double kg) {
    if (_user.weightUnit == 'lbs') {
      return '${(kg * 2.20462).toStringAsFixed(1)} lbs';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }


  String get _photoSubtitle {
    if (_photoCount == 0) return 'Not started';
    return '$_photoCount photo${_photoCount == 1 ? '' : 's'} taken';
  }

  // ── Goal progress ──────────────────────────────────────────────────────────
  double get _goalProgress {
    final target = _user.targetWeightKg;
    if (target == null) return 0;
    final start = _user.weightKg + (_user.goal == 'lose'
        ? (_user.dailyDeficitSurplus ?? 0) * -365 / 7700
        : 0);
    final current = _latestWeight ?? _user.weightKg;
    final total = (start - target).abs();
    if (total <= 0) return 1;
    final achieved = (start - current).abs().clamp(0.0, total);
    return achieved / total;
  }

  // ── Week summary stats ─────────────────────────────────────────────────────
  int get _daysLogged => _weekData.where((d) => d.logged).length;

  double get _avgCalories {
    final logged = _weekData.where((d) => d.logged).toList();
    if (logged.isEmpty) return 0;
    return logged.fold(0.0, (s, d) => s + d.calories) / logged.length;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text('Profile', style: AppTextStyles.headingLarge),
              ),
            ),

            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    _buildShimmer()
                  else ...[
                    _buildHeroCard(),
                    const SizedBox(height: 16),
                    _buildWeekSummaryCard(),
                    const SizedBox(height: 16),
                    _buildGoalsCard(),
                    const SizedBox(height: 16),
                    _buildNutritionSection(),
                    _buildTrackingSection(),
                    _buildWellbeingSection(),
                    _buildAppSection(),
                    _buildLogoutButton(),
                    const SizedBox(height: 32),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 1: Hero Card ───────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final initials = _user.name.isNotEmpty
        ? _user.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : '?';
    final weight = _latestWeight ?? _user.weightKg;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(initials.toUpperCase(),
                      style: AppTextStyles.headingMedium.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_user.name,
                        style: AppTextStyles.headingMedium.copyWith(
                            fontSize: 20)),
                    const SizedBox(height: 6),
                    // Goal pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_goalEmoji,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryAccent,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openEditProfile,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Edit profile',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primaryAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stat chips
          Row(children: [
            _statChip(_formatWeight(weight), 'Weight'),
            const SizedBox(width: 8),
            _statChip('${_user.targetCalories.round()} kcal', 'Daily target'),
            const SizedBox(width: 8),
            _statChip('$_currentStreak day streak', 'Streak'),
          ]),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Text(value,
                  style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primaryAccent)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      );

  // ── Section 2: Week Summary Card ──────────────────────────────────────────
  Widget _buildWeekSummaryCard() {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final daysLogged = _daysLogged;
    final avgCals = _avgCalories;
    final unloggedCount =
        _weekData.sublist(0, _todayIndex + 1).where((d) => !d.logged).length;
    final onTrack = unloggedCount == 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week',
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // 7-day bar chart
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final d = _weekData[i];
                final isToday = i == _todayIndex;
                Color barColor;
                double heightFrac = 0;

                if (d.isFuture) {
                  barColor = AppColors.divider;
                } else if (!d.logged) {
                  barColor = const Color(0xFF444444);
                  heightFrac = 0.15;
                } else if (d.calories > d.target * 1.05) {
                  barColor = AppColors.warning;
                  heightFrac = 1.0;
                } else {
                  barColor = AppColors.primaryAccent;
                  heightFrac = (d.calories / (d.target > 0 ? d.target : 2000))
                      .clamp(0.1, 1.0);
                }

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isToday)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            width: 18,
                            height: (56 * heightFrac).clamp(d.isFuture ? 0.0 : 4.0, 56.0),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? barColor
                                  : barColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dayLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? AppColors.primaryAccent
                                : AppColors.secondaryText,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          // Summary stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _weekStat('$daysLogged days', 'Logged'),
              _weekStat(
                  avgCals > 0 ? '${avgCals.round()} kcal' : '—',
                  'Avg/day'),
              _weekStat('$_currentStreak day', 'Streak'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            onTrack
                ? "You're on track this week"
                : "$unloggedCount day${unloggedCount == 1 ? '' : 's'} without logging this week",
            style: AppTextStyles.caption.copyWith(
              color: onTrack ? AppColors.primaryAccent : AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekStat(String value, String label) => Column(
        children: [
          Text(value,
              style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label,
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      );

  // ── Section 3: Goals Card ─────────────────────────────────────────────────
  Widget _buildGoalsCard() {
    final tw = _user.targetWeightKg;
    final currentW = _latestWeight ?? _user.weightKg;
    final progress = _goalProgress.clamp(0.0, 1.0);
    final goalEndDate = _user.goalEndDate;

    String formattedDate = '—';
    if (goalEndDate != null) {
      try {
        final dt = DateTime.parse(goalEndDate);
        const months = [
          'Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'
        ];
        formattedDate =
            '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Goals',
              style:
                  AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _goalRow('Current weight', _formatWeight(currentW)),
          _goalRow('Target weight', tw != null ? _formatWeight(tw) : '—'),
          _goalRow(
              'Daily target', '${_user.targetCalories.round()} kcal'),
          _goalRow('Goal date', formattedDate),

          if (tw != null && _user.goal != 'maintain') ...[
            const SizedBox(height: 14),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% of goal',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primaryAccent),
                  ),
                  const Spacer(),
                  Text(
                    '${(currentW - tw).abs().toStringAsFixed(1)} kg to go',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.secondaryText),
                  ),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryAccent),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openRecalculate,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryAccent,
                side: const BorderSide(color: AppColors.primaryAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Recalculate my plan',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.primaryAccent, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
              child: Text(label, style: AppTextStyles.bodySecondary)),
          Text(value,
              style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      );

  // ── Section 4: Nutrition ──────────────────────────────────────────────────
  Widget _buildNutritionSection() {
    return SettingsSection(
      title: 'Nutrition',
      children: [
        SettingsRow(
          icon: Icons.egg_outlined,
          label: 'Protein preference',
          subtitle: 'Affects daily protein targets',
          trailing: _proteinPrefLabel,
          onTap: _pickProteinPreference,
        ),
        SettingsRow(
          icon: Icons.calendar_today_rounded,
          label: 'Check-in day',
          subtitle: 'Day of weekly recalculation',
          trailing: _checkinDayLabel,
          onTap: _pickCheckinDay,
        ),
        SettingsRow(
          icon: Icons.scale_rounded,
          label: 'Weight unit',
          trailing: _user.weightUnit.toUpperCase(),
          onTap: _toggleWeightUnit,
          showChevron: false,
          isLast: true,
        ),
      ],
    );
  }

  // ── Section 5: Tracking ───────────────────────────────────────────────────
  Widget _buildTrackingSection() {
    return SettingsSection(
      title: 'Tracking',
      children: [
        SettingsRow(
          icon: Icons.photo_camera_outlined,
          label: 'Progress Photos',
          subtitle: _photoSubtitle,
          onTap: _openProgressPhotos,
        ),
        SettingsToggleRow(
          icon: Icons.notifications_outlined,
          label: 'Photo reminders',
          subtitle: _photoReminderEnabled
              ? 'Tap to change frequency'
              : 'Get reminded to take photos',
          value: _photoReminderEnabled,
          onChanged: _togglePhotoReminder,
        ),
        if (_photoReminderEnabled)
          SettingsRow(
            icon: Icons.timer_outlined,
            label: 'Reminder frequency',
            trailing: _photoReminderIntervalDays == 14
                ? 'Every 2 wks'
                : _photoReminderIntervalDays == 21
                    ? 'Every 3 wks'
                    : 'Every 4 wks',
            onTap: _pickReminderInterval,
          ),
        SettingsRow(
          icon: Icons.monitor_weight_outlined,
          label: 'Weight logging',
          subtitle: 'Track your weight over time',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Log weight from the Dashboard tab'),
              backgroundColor: AppColors.cardSurface,
            ));
          },
          isLast: true,
        ),
      ],
    );
  }

  // ── Section 6: Wellbeing ──────────────────────────────────────────────────
  Widget _buildWellbeingSection() {
    return SettingsSection(
      title: 'Wellbeing',
      children: [
        SettingsToggleRow(
          icon: Icons.spa_rounded,
          label: 'Supportive Mode',
          subtitle:
              'Fewer check-ins and suggestions. Recommended if tracking feels stressful.',
          value: _lowPressureMode,
          onChanged: _toggleLowPressure,
        ),
        SettingsToggleRow(
          icon: Icons.local_fire_department_outlined,
          label: 'Hide streak counter',
          subtitle: 'Remove the streak display if you find it adds pressure.',
          value: _hideStreakCounter,
          onChanged: _toggleHideStreak,
        ),
        SettingsRow(
          icon: Icons.emergency_outlined,
          label: 'Emergency adjust',
          subtitle: 'Went over today? Tap here to adjust your plan.',
          iconColor: AppColors.warning,
          onTap: _openEmergencySheet,
          isLast: true,
        ),
      ],
    );
  }

  // ── Section 7: App ────────────────────────────────────────────────────────
  Widget _buildAppSection() {
    return SettingsSection(
      title: 'App',
      children: [
        SettingsRow(
          icon: Icons.lock_outline,
          label: 'Data & Privacy',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DataPrivacyScreen()),
          ),
        ),
        SettingsRow(
          icon: Icons.share_outlined,
          label: 'Share with a friend',
          onTap: _shareApp,
        ),
        SettingsRow(
          icon: Icons.info_outline,
          label: 'About',
          subtitle: 'v1.0.0',
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardSurface,
              title: Text('About', style: AppTextStyles.headingMedium),
              content: Text(
                'v1.0.0\n\nThank you for using this app. Your health journey matters.\n\nPrivacy policy: healthapp.example.com/privacy',
                style: AppTextStyles.bodySecondary,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: AppTextStyles.captionAccent),
                ),
              ],
            ),
          ),
          isLast: true,
        ),
      ],
    );
  }

  // ── Section 8: Logout ─────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.destructive,
            side: const BorderSide(color: AppColors.destructive, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Shimmer loading ───────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.cardSurface,
      highlightColor: const Color(0xFF2A2A2A),
      child: Column(children: [
        _shimmerBox(height: 130, radius: 16),
        const SizedBox(height: 16),
        _shimmerBox(height: 160, radius: 16),
        const SizedBox(height: 16),
        _shimmerBox(height: 180, radius: 16),
        const SizedBox(height: 16),
        _shimmerBox(height: 200, radius: 16),
        const SizedBox(height: 16),
        _shimmerBox(height: 180, radius: 16),
      ]),
    );
  }

  Widget _shimmerBox({required double height, double radius = 8}) =>
      Container(
        width: double.infinity,
        height: height,
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ── Data class for week summary ────────────────────────────────────────────────
class _DayData {
  final double calories;
  final double target;
  final bool logged;
  final bool isFuture;

  const _DayData({
    this.calories = 0,
    this.target = 0,
    this.logged = false,
    this.isFuture = false,
  });
}
