// [HEALTH APP] — Pantry Service
// Handles all Supabase read/write for user_pantry and saved_recipes tables.
// All callers pass userId explicitly — never reads auth state itself.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/recipe_result.dart';

class PantryService {
  PantryService._();
  static final PantryService instance = PantryService._();

  final _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Pantry — user's default available foods
  // ---------------------------------------------------------------------------

  /// Loads all saved pantry food names for [userId].
  Future<List<String>> loadPantry(String userId) async {
    try {
      final data = await _client
          .from('user_pantry')
          .select('food_name')
          .eq('user_id', userId)
          .order('created_at');
      return (data as List).map((e) => e['food_name'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a single food to the user's saved pantry.
  Future<void> addPantryItem(String userId, String foodName) async {
    try {
      await _client.from('user_pantry').insert({
        'user_id': userId,
        'food_name': foodName.trim(),
      });
    } catch (_) {}
  }

  /// Removes a single food from the user's saved pantry.
  Future<void> removePantryItem(String userId, String foodName) async {
    try {
      await _client
          .from('user_pantry')
          .delete()
          .eq('user_id', userId)
          .eq('food_name', foodName);
    } catch (_) {}
  }

  /// Replaces the user's entire pantry with [foods].
  /// Atomic: deletes all, then inserts new list.
  Future<void> replacePantry(String userId, List<String> foods) async {
    try {
      await _client.from('user_pantry').delete().eq('user_id', userId);
      if (foods.isEmpty) return;
      await _client.from('user_pantry').insert(
        foods
            .map((f) => {'user_id': userId, 'food_name': f.trim()})
            .toList(),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Saved Recipes
  // ---------------------------------------------------------------------------

  /// Saves a recipe to [saved_recipes] for [userId].
  Future<void> saveRecipe(String userId, RecipeResult recipe) async {
    try {
      await _client.from('saved_recipes').insert({
        'user_id': userId,
        'recipe_name': recipe.recipeName,
        'recipe_data': recipe.toJson(),
      });
    } catch (_) {}
  }

  /// Loads all saved recipes for [userId], newest first.
  Future<List<RecipeResult>> loadSavedRecipes(String userId) async {
    try {
      final data = await _client
          .from('saved_recipes')
          .select('recipe_data')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => RecipeResult.fromJson(e['recipe_data'] as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
