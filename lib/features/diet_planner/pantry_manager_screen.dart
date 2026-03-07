// [HEALTH APP] — Pantry Manager Screen
// Full-screen editor for the user's saved (default) pantry.
// Changes saved here persist to Supabase user_pantry table.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pantry_service.dart';
import 'food_input_sheet.dart';

class PantryManagerScreen extends StatefulWidget {
  const PantryManagerScreen({super.key});

  @override
  State<PantryManagerScreen> createState() => _PantryManagerScreenState();
}

class _PantryManagerScreenState extends State<PantryManagerScreen> {
  List<String> _pantry = [];
  bool _loading = true;
  bool _saving = false;

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await PantryService.instance.loadPantry(_userId);
    if (mounted) setState(() { _pantry = items; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await PantryService.instance.replacePantry(_userId, _pantry);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Pantry saved ✓', style: TextStyle(color: Colors.white)),
      backgroundColor: AppColors.primaryAccent,
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.of(context).pop();
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodInputSheet(
        initialSelected: List.from(_pantry),
        onDone: (updated) => setState(() => _pantry = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Pantry',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryAccent)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These foods appear by default when you generate a plan. '
                    'Edit anytime.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Add bar
                  GestureDetector(
                    onTap: _openAddSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: Colors.white38, size: 18),
                          const SizedBox(width: 10),
                          const Text('Search & add foods...',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 14)),
                          const Spacer(),
                          Icon(Icons.add,
                              color: AppColors.primaryAccent, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Food count
                  Text(
                    '${_pantry.length} item${_pantry.length == 1 ? '' : 's'} saved',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  // Chip grid
                  Expanded(
                    child: _pantry.isEmpty
                        ? const Center(
                            child: Text(
                              'No foods saved yet.\nTap above to add your usual foods.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic),
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _pantry
                                .map((food) => Chip(
                                      label: Text(
                                        food.length > 15
                                            ? '${food.substring(0, 15)}…'
                                            : food,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13),
                                      ),
                                      backgroundColor:
                                          const Color(0xFF2A2A2A),
                                      side: const BorderSide(
                                          color: Colors.white12),
                                      deleteIcon: const Icon(Icons.close,
                                          size: 14,
                                          color: Colors.white38),
                                      onDeleted: () => setState(
                                          () => _pantry.remove(food)),
                                    ))
                                .toList(),
                          ),
                  ),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.black)))
                          : const Text('Save Pantry',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}
