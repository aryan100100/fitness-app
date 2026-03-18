// [HEALTH APP] â€” Profile & Settings Screen
// Full profile screen replacing the dev-only placeholder.
// Shows user info summary, settings toggles, and account actions.
// CHANGELOG: Replaces dev_profile_screen.dart with full profile settings.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../models/user_model.dart';
import '../onboarding/onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  // ---- Weight unit toggle ----
  Future<void> _toggleWeightUnit() async {
    final newUnit = _user.weightUnit == 'kg' ? 'lbs' : 'kg';
    setState(() => _user = _user.copyWith(weightUnit: newUnit));
    await _saveField({'weight_unit': newUnit});
  }

  // ---- Check-in day picker ----
  Future<void> _pickCheckinDay() async {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Weekly Check-in Day', style: AppTextStyles.headingMedium),
        children: List.generate(7, (i) {
          final isSelected = _user.checkinDay == i + 1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, i + 1),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  days[i],
                  style: AppTextStyles.body.copyWith(
                    color: isSelected ? AppColors.primaryAccent : AppColors.primaryText,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
    if (picked != null && picked != _user.checkinDay) {
      setState(() => _user = _user.copyWith(checkinDay: picked));
      await _saveField({'checkin_day': picked});
    }
  }

  // ---- Low-pressure mode toggle ----
  Future<void> _toggleLowPressureMode(bool value) async {
    setState(() => _user = _user.copyWith(lowPressureMode: value));
    await _saveField({'low_pressure_mode': value});
  }

  // ---- Persist a field change to Supabase ----
  Future<void> _saveField(Map<String, dynamic> fields) async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.instance.updateUser(fields);
    } catch (e) {
      debugPrint('[PROFILE] save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not save — check your connection'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ---- Sign out ----
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Sign Out', style: AppTextStyles.headingMedium),
        content: Text(
          'You will need to complete onboarding again if you sign out.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  // ---- Helpers ----
  String get _checkinDayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = (_user.checkinDay - 1).clamp(0, 6);
    return days[idx];
  }

  String get _goalLabel {
    switch (_user.goal) {
      case 'lose':
        return 'Lose Weight';
      case 'gain':
        return 'Gain Weight';
      default:
        return 'Maintain Weight';
    }
  }

  String get _activityLabel {
    switch (_user.activityLevel) {
      case 'sedentary':
        return 'Sedentary';
      case 'lightly_active':
        return 'Lightly Active';
      case 'moderately_active':
        return 'Moderately Active';
      case 'very_active':
        return 'Very Active';
      default:
        return _user.activityLevel;
    }
  }

  String _formatWeight(double kg) {
    if (_user.weightUnit == 'lbs') {
      return '${(kg * 2.20462).toStringAsFixed(1)} lbs';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ---- App Bar ----
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text('Profile', style: AppTextStyles.headingLarge),
                    const Spacer(),
                    if (_isSaving)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.primaryAccent),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // ---- User Info Card ----
                  _buildUserCard(),
                  const SizedBox(height: 20),

                  // ---- Nutrition Snapshot ----
                  _sectionTitle('Daily Targets'),
                  const SizedBox(height: 8),
                  _buildNutritionCard(),
                  const SizedBox(height: 20),

                  // ---- Settings ----
                  _sectionTitle('Settings'),
                  const SizedBox(height: 8),
                  _settingsTile(
                    icon: Icons.scale_rounded,
                    label: 'Weight Unit',
                    trailing: _user.weightUnit.toUpperCase(),
                    onTap: _toggleWeightUnit,
                  ),
                  _settingsTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Check-in Day',
                    trailing: _checkinDayLabel,
                    onTap: _pickCheckinDay,
                  ),
                  _switchTile(
                    icon: Icons.spa_rounded,
                    label: 'Low Pressure Mode',
                    subtitle: 'Softer nudges, no guilt-based prompts',
                    value: _user.lowPressureMode,
                    onChanged: _toggleLowPressureMode,
                  ),
                  const SizedBox(height: 20),

                  // ---- Account ----
                  _sectionTitle('Account'),
                  const SizedBox(height: 8),
                  _settingsTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    textColor: AppColors.destructive,
                    onTap: _signOut,
                    showChevron: false,
                  ),

                  const SizedBox(height: 32),

                  // ---- App version ----
                  Center(
                    child: Text(
                      'v1.0.0  ·  Built with ❤️',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Sub-widgets
  // ==========================================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.caption.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: AppColors.secondaryText,
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryAccent,
                  AppColors.primaryAccent.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _user.name.isNotEmpty ? _user.name[0].toUpperCase() : '?',
                style: AppTextStyles.headingMedium.copyWith(
                  color: Colors.white, fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_user.name, style: AppTextStyles.headingMedium.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  '$_goalLabel  •  ${_user.age}y  •  $_activityLabel',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatWeight(_user.weightKg)}  •  ${_user.heightCm.toStringAsFixed(0)} cm',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroColumn('Calories', '${_user.targetCalories.round()}', AppColors.primaryAccent),
          _verticalDivider(),
          _macroColumn('Protein', '${_user.proteinG.round()}g', AppColors.proteinBar),
          _verticalDivider(),
          _macroColumn('Carbs', '${_user.carbsG.round()}g', AppColors.carbBar),
          _verticalDivider(),
          _macroColumn('Fat', '${_user.fatG.round()}g', AppColors.fatBar),
        ],
      ),
    );
  }

  Widget _macroColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 17,
        )),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1, height: 32,
      color: AppColors.divider,
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? trailing,
    Color? textColor,
    required VoidCallback onTap,
    bool showChevron = true,
  }) {
    final color = textColor ?? AppColors.primaryText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          margin: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: color))),
              if (trailing != null)
                Text(trailing, style: AppTextStyles.body.copyWith(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.w600,
                )),
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryAccent,
          ),
        ],
      ),
    );
  }
}

