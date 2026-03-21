// [HEALTH APP] — Edit Profile Screen (Profile Feature)
// Allows editing all personal details and recalculates TDEE on save.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/tdee_calculator.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _targetWeightCtrl;

  // Selectors
  late String _biologicalSex;
  late String _goal;
  late String _activityLevel;
  late String _lifeSituation;
  late String _region;
  late String _proteinPreference;
  late String _liftingExperience;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u.name);
    _ageCtrl = TextEditingController(text: u.age.toString());
    _heightCtrl = TextEditingController(text: u.heightCm.toStringAsFixed(0));
    _weightCtrl = TextEditingController(text: u.weightKg.toStringAsFixed(1));
    _targetWeightCtrl = TextEditingController(
        text: u.targetWeightKg?.toStringAsFixed(1) ?? '');

    _biologicalSex = u.biologicalSex;
    _goal = u.goal;
    _activityLevel = u.activityLevel;
    _lifeSituation = u.lifeSituation;
    _region = u.region;
    _proteinPreference = u.proteinPreference;
    _liftingExperience = u.liftingExperience ?? 'none';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text) ?? widget.user.age;
    final height =
        double.tryParse(_heightCtrl.text) ?? widget.user.heightCm;
    final weight =
        double.tryParse(_weightCtrl.text) ?? widget.user.weightKg;
    final targetWeight = double.tryParse(_targetWeightCtrl.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Please enter your name'),
        backgroundColor: AppColors.cardSurface,
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build updated user model for TDEE recalculation
      final updatedUser = widget.user.copyWith(
        name: name,
        age: age,
        heightCm: height,
        weightKg: weight,
        targetWeightKg: targetWeight,
        biologicalSex: _biologicalSex,
        goal: _goal,
        activityLevel: _activityLevel,
        lifeSituation: _lifeSituation,
        region: _region,
        proteinPreference: _proteinPreference,
        liftingExperience: _liftingExperience,
      );

      final pace = updatedUser.weeklyPacePercent ?? 0.75;
      final plan = TDEECalculator.calculateAll(
        user: updatedUser,
        weeklyPacePercent: pace,
      );

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await Supabase.instance.client.from('users').update({
        'name': name,
        'age': age,
        'height_cm': height,
        'weight_kg': weight,
        'target_weight_kg': targetWeight,
        'biological_sex': _biologicalSex,
        'goal': _goal,
        'activity_level': _activityLevel,
        'life_situation': _lifeSituation,
        'region': _region,
        'protein_preference': _proteinPreference,
        'lifting_experience': _liftingExperience,
        'tdee': plan.tdee,
        'target_calories': plan.targetCalories,
        'protein_g': plan.proteinG,
        'carbs_g': plan.carbsG,
        'fat_g': plan.fatG,
        'fiber_g': plan.fiberG,
        'protein_multiplier': plan.proteinMultiplier,
        'daily_deficit_surplus': plan.dailyDeficitSurplus,
        'weekly_pace_percent': pace,
      }).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated ✅ Your targets have been recalculated.'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true); // signal refresh
    } catch (e) {
      debugPrint('[EDIT PROFILE] save error: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Couldn't save — please try again"),
          backgroundColor: AppColors.destructive,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.primaryText,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Personal ────────────────────────────────────────────────────────
          _sectionHeader('Personal'),
          _textField('Full name', _nameCtrl),
          _textField('Age', _ageCtrl, numeric: true),
          _textField('Height (cm)', _heightCtrl, numeric: true),

          // Biological sex toggle
          _label('Biological sex'),
          _segmentedPicker(
            options: const ['male', 'female'],
            labels: const ['Male', 'Female'],
            value: _biologicalSex,
            onChanged: (v) => setState(() => _biologicalSex = v),
          ),

          const SizedBox(height: 20),

          // ── Goal ─────────────────────────────────────────────────────────────
          _sectionHeader('Goal'),
          _textField('Current weight (kg)', _weightCtrl, numeric: true),
          _textField('Target weight (kg, optional)',
              _targetWeightCtrl, numeric: true),
          _label('Goal'),
          _segmentedPicker(
            options: const ['lose', 'gain', 'maintain'],
            labels: const ['Lose weight', 'Gain muscle', 'Maintain'],
            value: _goal,
            onChanged: (v) => setState(() => _goal = v),
          ),

          const SizedBox(height: 20),

          // ── Activity ──────────────────────────────────────────────────────────
          _sectionHeader('Activity'),
          _label('Activity level'),
          _columnPicker(
            options: const [
              'sedentary',
              'lightly_active',
              'moderately_active',
              'very_active'
            ],
            labels: const [
              'Sedentary (desk job, no exercise)',
              'Lightly active (1–3 workouts/week)',
              'Moderately active (3–5 workouts/week)',
              'Very active (6–7 workouts/week)',
            ],
            value: _activityLevel,
            onChanged: (v) => setState(() => _activityLevel = v),
          ),
          _label('Life situation'),
          _columnPicker(
            options: const [
              'hostel_student',
              'office_worker',
              'work_from_home',
              'homemaker',
              'other',
            ],
            labels: const [
              'Hostel student',
              'Office worker',
              'Work from home',
              'Homemaker',
              'Other',
            ],
            value: _lifeSituation,
            onChanged: (v) => setState(() => _lifeSituation = v),
          ),
          _label('Region'),
          _columnPicker(
            options: const [
              'North India',
              'South India',
              'West India',
              'East India',
              'Other',
            ],
            labels: const [
              'North India',
              'South India',
              'West India',
              'East India',
              'Other',
            ],
            value: _region,
            onChanged: (v) => setState(() => _region = v),
          ),

          const SizedBox(height: 20),

          // ── Nutrition ─────────────────────────────────────────────────────────
          _sectionHeader('Nutrition'),
          _label('Protein preference'),
          _segmentedPicker(
            options: const ['comfortable', 'moderate', 'high'],
            labels: const ['Comfortable', 'Moderate', 'High'],
            value: _proteinPreference,
            onChanged: (v) => setState(() => _proteinPreference = v),
          ),
          const SizedBox(height: 16),
          _label('Lifting experience'),
          _segmentedPicker(
            options: const ['none', 'beginner', 'intermediate', 'advanced'],
            labels: const ['None', 'Beginner', 'Intermediate', 'Advanced'],
            value: _liftingExperience,
            onChanged: (v) => setState(() => _liftingExperience = v),
          ),

          const SizedBox(height: 32),

          // ── Save button ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text('Save changes', style: AppTextStyles.buttonLabel),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(t.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.secondaryText,
            )),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: AppTextStyles.bodySecondary),
      );

  Widget _textField(String label, TextEditingController ctrl,
      {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : [],
          style: AppTextStyles.body,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AppTextStyles.caption,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primaryAccent, width: 1.5)),
          ),
        ),
      );

  Widget _segmentedPicker({
    required List<String> options,
    required List<String> labels,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(options.length, (i) {
          final selected = value == options[i];
          return GestureDetector(
            onTap: () => onChanged(options[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryAccent
                    : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? AppColors.primaryAccent
                        : AppColors.divider),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.black : AppColors.primaryText,
                  )),
            ),
          );
        }),
      ),
    );
  }

  Widget _columnPicker({
    required List<String> options,
    required List<String> labels,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: List.generate(options.length, (i) {
          final selected = value == options[i];
          return GestureDetector(
            onTap: () => onChanged(options[i]),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryAccent.withValues(alpha: 0.12)
                    : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected
                        ? AppColors.primaryAccent
                        : AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          color: selected
                              ? AppColors.primaryAccent
                              : AppColors.primaryText,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primaryAccent, size: 18),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
