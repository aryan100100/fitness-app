// [HEALTH APP] — Recipe Tab
// AI recipe generator. Uses Gemini 1.5 Flash.
// Optional macro-fit toggle adjusts recipe to remaining daily macros.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/gemini_service.dart';
import '../../../models/recipe_result.dart';
import '../../../models/user_model.dart';
import 'widgets/recipe_result_card.dart';

// Daily suggestion chips rotate by day-of-month
const List<List<String>> _dailySuggestions = [
  ['High protein breakfast', 'Quick dal recipe', 'Egg-based meal'],
  ['Chicken rice bowl', 'Paneer stir fry', 'Oats smoothie'],
  ['Rajma chawal', 'Protein omelette', 'Banana peanut butter shake'],
];

enum _RecipeState { idle, loading, loaded, error }

class RecipeTab extends StatefulWidget {
  final UserModel user;
  const RecipeTab({super.key, required this.user});

  @override
  State<RecipeTab> createState() => _RecipeTabState();
}

class _RecipeTabState extends State<RecipeTab>
    with AutomaticKeepAliveClientMixin {
  final _textCtrl = TextEditingController();
  _RecipeState _state = _RecipeState.idle;
  RecipeResult? _recipe;
  bool _fitMacros = false;
  Timer? _slowTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _textCtrl.dispose();
    _slowTimer?.cancel();
    super.dispose();
  }

  List<String> get _suggestions {
    final idx = DateTime.now().day % _dailySuggestions.length;
    return _dailySuggestions[idx];
  }

  Future<void> _generate() async {
    final query = _textCtrl.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _state = _RecipeState.loading; _recipe = null; });

    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _state == _RecipeState.loading) setState(() {});
    });

    try {
      // Calculate remaining macros if fitMacros toggle is on
      double? remCal, remProt, remCarbs, remFat;
      if (_fitMacros) {
        final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        if (userId.isNotEmpty) {
          try {
            final today = _todayStr();
            final rows = await Supabase.instance.client
                .from('food_logs')
                .select('calories, protein_g, carbs_g, fat_g')
                .eq('user_id', userId)
                .eq('date', today);
            double loggedCal = 0, loggedProt = 0, loggedCarbs = 0, loggedFat = 0;
            for (final r in (rows as List)) {
              loggedCal   += (r['calories']  as num?)?.toDouble() ?? 0;
              loggedProt  += (r['protein_g'] as num?)?.toDouble() ?? 0;
              loggedCarbs += (r['carbs_g']   as num?)?.toDouble() ?? 0;
              loggedFat   += (r['fat_g']     as num?)?.toDouble() ?? 0;
            }
            remCal   = (widget.user.targetCalories - loggedCal).clamp(0, double.infinity);
            remProt  = (widget.user.proteinG       - loggedProt).clamp(0, double.infinity);
            remCarbs = (widget.user.carbsG         - loggedCarbs).clamp(0, double.infinity);
            remFat   = (widget.user.fatG           - loggedFat).clamp(0, double.infinity);
          } catch (_) {}
        }
      }

      final result = await GeminiService.instance.generateRecipeResult(
        query: query,
        user: widget.user,
        fitMacros: _fitMacros,
        remCalories: remCal,
        remProtein: remProt,
        remCarbs: remCarbs,
        remFat: remFat,
      );

      _slowTimer?.cancel();
      if (!mounted) return;
      if (result != null) {
        setState(() { _state = _RecipeState.loaded; _recipe = result; });
      } else {
        setState(() => _state = _RecipeState.error);
      }
    } catch (_) {
      _slowTimer?.cancel();
      if (mounted) setState(() => _state = _RecipeState.error);
    }
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4,'0')}-'
        '${n.month.toString().padLeft(2,'0')}-'
        '${n.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Title
          const Text('Generate a Recipe',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Tell Gemini what you want to cook',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          // Input
          TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter a dish name or ingredient...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primaryAccent, width: 2),
              ),
              suffixIcon: Icon(Icons.search,
                  color: Colors.white38, size: 20),
            ),
            onSubmitted: (_) => _generate(),
          ),
          const SizedBox(height: 12),
          // Daily suggestion chips
          Wrap(
            spacing: 8,
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      backgroundColor: const Color(0xFF2A2A2A),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () {
                        _textCtrl.text = s;
                        _generate();
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          // Macro-fit toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fit my macro targets',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(
                      _fitMacros
                          ? 'Recipe quantities adjusted to your remaining macros'
                          : 'Standard recipe — ignores remaining macros',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                Switch(
                  value: _fitMacros,
                  onChanged: (v) => setState(() => _fitMacros = v),
                  activeThumbColor: AppColors.primaryAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _state == _RecipeState.loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _state == _RecipeState.loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black)),
                        ),
                        SizedBox(width: 10),
                        Text('Generating...',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ],
                    )
                  : const Text('Get Recipe',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('Powered by Gemini AI',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
          ),
          const SizedBox(height: 20),
          // States
          if (_state == _RecipeState.loading)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryAccent)),
                  const SizedBox(height: 14),
                  Text(
                    'Generating your recipe...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (_state == _RecipeState.error)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white38, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'Unable to generate — tap Get Recipe to retry',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (_state == _RecipeState.loaded && _recipe != null)
            RecipeResultCard(recipe: _recipe!, user: widget.user),
        ],
      ),
    );
  }
}
