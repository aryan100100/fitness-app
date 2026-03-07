// [HEALTH APP] — Recipe Result Card
// Displays a generated recipe with a live serving-size scaler.
// All quantities and macros scale in real-time when servings change.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/diet_planner_service.dart';
import '../../../../core/services/pantry_service.dart';
import '../../../../models/recipe_result.dart';
import '../../../../models/user_model.dart';

class RecipeResultCard extends StatefulWidget {
  final RecipeResult recipe;
  final UserModel user;

  const RecipeResultCard({
    super.key,
    required this.recipe,
    required this.user,
  });

  @override
  State<RecipeResultCard> createState() => _RecipeResultCardState();
}

class _RecipeResultCardState extends State<RecipeResultCard> {
  int _servings = 1;
  bool _logging = false;
  bool _logged = false;
  bool _saving = false;
  bool _saved = false;

  RecipeResult get _r => widget.recipe;

  NutritionPerServing get _scaledNutrition =>
      _r.nutritionPerServing * _servings.toDouble();

  Future<void> _logRecipe() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    setState(() => _logging = true);
    try {
      final n = _scaledNutrition;
      await DietPlannerService.instance.logRecipe(
        userId: userId,
        recipeName: _r.recipeName,
        mealType: 'snack',
        calories: n.calories,
        protein: n.protein,
        carbs: n.carbs,
        fat: n.fat,
        fibre: n.fibre,
        servings: _servings,
      );
      if (mounted) {
        setState(() => _logged = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Recipe logged to your diary 🎉',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primaryAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _saveRecipe() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await PantryService.instance.saveRecipe(userId, _r);
      if (mounted) setState(() => _saved = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _scaledNutrition;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_r.recipeName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _timeChip(Icons.alarm_outlined,
                        'Prep ${_r.prepTimeMinutes}m'),
                    const SizedBox(width: 8),
                    _timeChip(
                        Icons.outdoor_grill_outlined, 'Cook ${_r.cookTimeMinutes}m'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Serving selector
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('Serves:',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.white54, size: 22),
                  onPressed: _servings > 1
                      ? () => setState(() => _servings--)
                      : null,
                ),
                Text('$_servings',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: AppColors.primaryAccent, size: 22),
                  onPressed: () => setState(() => _servings++),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Ingredients
          _sectionTitle('Ingredients'),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: _r.ingredients
                  .map((ing) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(ing.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                            Text(
                              ing.scaledQuantity(_servings.toDouble()),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Instructions
          _sectionTitle('Instructions'),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: _r.instructions
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 10, top: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAccent
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${e.key + 1}',
                                    style: TextStyle(
                                        color: AppColors.primaryAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            Expanded(
                              child: Text(e.value,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.5)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Macro breakdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Per ${_servings == 1 ? 'serving' : '$_servings servings'}',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _macroChip('${n.calories.toInt()} kcal',
                        AppColors.primaryAccent),
                    const SizedBox(width: 6),
                    _macroChip('P: ${n.protein.toInt()}g',
                        const Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    _macroChip('C: ${n.carbs.toInt()}g',
                        const Color(0xFF2196F3)),
                    const SizedBox(width: 6),
                    _macroChip('F: ${n.fat.toInt()}g',
                        const Color(0xFFFF9800)),
                  ],
                ),
                if (_r.macroNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_r.macroNote,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          // AI disclaimer
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text('AI Generated — values are estimates',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Log
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_logged || _logging) ? null : _logRecipe,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _logged
                              ? Colors.white24
                              : AppColors.primaryAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _logging
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _logged ? '✅ Logged' : 'Log Recipe',
                            style: TextStyle(
                                color: _logged
                                    ? Colors.white24
                                    : AppColors.primaryAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                // Save
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_saved || _saving) ? null : _saveRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved
                          ? Colors.white12
                          : AppColors.primaryAccent,
                      foregroundColor:
                          _saved ? Colors.white38 : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black)))
                        : Text(_saved ? '✅ Saved' : 'Save Recipe',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      );

  Widget _timeChip(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 13, color: Colors.white38),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      );

  Widget _macroChip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}
