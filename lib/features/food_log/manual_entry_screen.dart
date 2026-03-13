// [HEALTH APP] — Manual Food Entry Screen
// For foods not found in any database tier.
// Saves to both food_logs and custom_foods tables.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/streak_service.dart';
import '../../models/user_model.dart';

class ManualEntryScreen extends StatefulWidget {
  final String mealType;
  final UserModel user;
  final String? prefillName;

  const ManualEntryScreen({
    super.key,
    required this.mealType,
    required this.user,
    this.prefillName,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _calCtrl    = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl  = TextEditingController();
  final _fatCtrl    = TextEditingController();
  final _fibreCtrl  = TextEditingController();
  bool _isSaving = false;

  String get _mealLabel => switch (widget.mealType) {
    'breakfast' => 'Breakfast',
    'lunch'     => 'Lunch',
    'dinner'    => 'Dinner',
    _           => 'Snacks',
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fibreCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final cal    = double.tryParse(_calCtrl.text) ?? 0;
      final prot   = double.tryParse(_proteinCtrl.text) ?? 0;
      final carbs  = double.tryParse(_carbsCtrl.text) ?? 0;
      final fat    = double.tryParse(_fatCtrl.text) ?? 0;
      final fibre  = double.tryParse(_fibreCtrl.text) ?? 0;

      // Save to food_logs
      await Supabase.instance.client.from('food_logs').insert({
        'user_id':          userId,
        'date':             dateStr,
        'meal_type':        widget.mealType,
        'food_name':        _nameCtrl.text.trim(),
        'quantity_g':       100.0,
        'calories':         cal,
        'protein_g':        prot,
        'carbs_g':          carbs,
        'fat_g':            fat,
        'fibre_g':          fibre,
        'food_source':      'custom',
        'is_photo_estimate': false,
      });

      // Also persist to custom_foods for future use
      Supabase.instance.client.from('custom_foods').insert({
        'user_id':           userId,
        'food_name':         _nameCtrl.text.trim(),
        'calories_per_100g': cal,
        'protein_per_100g':  prot,
        'carbs_per_100g':    carbs,
        'fat_per_100g':      fat,
        'fibre_per_100g':    fibre,
        'source':            'manual',
      }).ignore(); // Fire and forget — don't block on this

      try {
        await StreakService.instance.updateStreak(userId, today);
      } catch (e) {
        debugPrint('[STREAK] Error updating streak from manual log: $e');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t save — please try again',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryText)),
            backgroundColor: AppColors.cardSurface,
          ),
        );
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
        leading: const BackButton(color: AppColors.primaryText),
        title: Text('Add Custom Food', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adding to $_mealLabel',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryAccent),
              ),
              const SizedBox(height: 16),

              _Field(
                label: 'Food Name *',
                controller: _nameCtrl,
                required: true,
                textInputType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Calories (kcal) *',
                controller: _calCtrl,
                required: true,
                textInputType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Protein (g)',
                controller: _proteinCtrl,
                textInputType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Carbohydrates (g)',
                controller: _carbsCtrl,
                textInputType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Fat (g)',
                controller: _fatCtrl,
                textInputType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Fibre (g) — optional',
                controller: _fibreCtrl,
                textInputType: TextInputType.number,
              ),

              const SizedBox(height: 8),
              Text(
                'Values entered will be saved as-is (per your specified quantity). This food will be saved to your custom foods library for future logging.',
                style: AppTextStyles.caption,
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text('Add to $_mealLabel',
                          style: AppTextStyles.buttonLabel
                              .copyWith(color: Colors.black)),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType textInputType;

  const _Field({
    required this.label,
    required this.controller,
    this.required = false,
    required this.textInputType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: textInputType,
      style: AppTextStyles.body,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
