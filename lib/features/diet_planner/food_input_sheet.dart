// [HEALTH APP] — Food Input Sheet (Bottom Sheet) — v2
// Uses FoodSearchService (same 4-tier service as food logging screen).
// Uses FoodSearchService (3-tier: USDA, Indian local, Open Food Facts).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/food_search_service.dart';
import '../../../core/services/pantry_service.dart';
import '../../../models/food_search_result.dart';

// Category chips shown before user starts typing
const _categories = [
  (Icons.egg_alt_outlined, 'Eggs & Dairy'),
  (Icons.set_meal_outlined, 'Meat & Fish'),
  (Icons.bakery_dining_outlined, 'Grains & Bread'),
  (Icons.eco_outlined, 'Vegetables'),
  (Icons.apple, 'Fruits'),
  (Icons.rice_bowl_outlined, 'Dal & Pulses'),
  (Icons.local_drink_outlined, 'Beverages'),
  (Icons.cookie_outlined, 'Snacks'),
];

enum _SheetState { idle, searching, results, noResults }

class FoodInputSheet extends StatefulWidget {
  final List<String> initialSelected;
  final void Function(List<String>) onDone;

  const FoodInputSheet({
    super.key,
    required this.initialSelected,
    required this.onDone,
  });

  @override
  State<FoodInputSheet> createState() => _FoodInputSheetState();
}

class _FoodInputSheetState extends State<FoodInputSheet> {
  late final TextEditingController _textCtrl;
  late List<String> _selected;

  _SheetState _state = _SheetState.idle;
  List<FoodSearchResult> _results = [];
  List<String> _recentPantry = [];
  Timer? _debounce;
  String _lastQuery = '';

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _textCtrl = TextEditingController();
    _textCtrl.addListener(_onTextChanged);
    _loadRecentPantry();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentPantry() async {
    final items = await PantryService.instance.loadPantry(_userId);
    if (mounted) setState(() => _recentPantry = items.take(8).toList());
  }

  void _onTextChanged() {
    final query = _textCtrl.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() { _state = _SheetState.idle; _results = []; });
      return;
    }

    setState(() => _state = _SheetState.searching);

    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    try {
      final results =
          await FoodSearchService.instance.search(query, _userId);
      if (!mounted || _textCtrl.text.trim() != query) return;
      setState(() {
        _results = results;
        _state = results.isEmpty ? _SheetState.noResults : _SheetState.results;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _SheetState.noResults);
    }
  }

  void _selectByName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _selected.contains(trimmed)) return;
    setState(() => _selected.add(trimmed));
  }

  void _selectResult(FoodSearchResult r) => _selectByName(r.foodName);

  void _removeFood(String food) => setState(() => _selected.remove(food));

  void _setCategory(String label) {
    _textCtrl.text = label;
    _textCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: label.length));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('What do you have available?',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
              ),

              // Selected chips row
              if (_selected.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _selected.map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          f.length > 15 ? '${f.substring(0, 15)}…' : f,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        backgroundColor:
                            AppColors.primaryAccent.withValues(alpha: 0.2),
                        side: BorderSide(
                            color: AppColors.primaryAccent.withValues(alpha: 0.4)),
                        deleteIcon: const Icon(Icons.close,
                            size: 14, color: Colors.white54),
                        onDeleted: () => _removeFood(f),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    )).toList(),
                  ),
                ),

              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search any food, ingredient, or dish...',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white38, size: 20),
                    suffixIcon: _textCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white38, size: 18),
                            onPressed: () {
                              _textCtrl.clear();
                              setState(() {
                                _state = _SheetState.idle;
                                _results = [];
                              });
                            })
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              // Category chips (always visible)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _categories.map((cat) {
                    final (icon, label) = cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(label,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        backgroundColor: const Color(0xFF2A2A2A),
                        side: const BorderSide(color: Colors.white12),
                        padding: EdgeInsets.zero,
                        onPressed: () => _setCategory(label),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Content area
              Expanded(child: _buildContent(scrollCtrl)),

              // Done button
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDone(_selected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Done'
                          : 'Done  (${_selected.length} food${_selected.length == 1 ? '' : 's'} selected)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollCtrl) {
    switch (_state) {
      case _SheetState.searching:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryAccent)),
              SizedBox(height: 12),
              Text('Searching...', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        );

      case _SheetState.results:
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _results.length,
          itemBuilder: (_, i) => _ResultRow(
            result: _results[i],
            isSelected: _selected.contains(_results[i].foodName),
            onTap: () => _selectResult(_results[i]),
          ),
        );

      case _SheetState.noResults:
        final query = _textCtrl.text.trim();
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No results for "$query"',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _selectByName(query),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primaryAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(Icons.add, color: AppColors.primaryAccent, size: 18),
                label: Text('Add "$query" anyway',
                    style: TextStyle(color: AppColors.primaryAccent)),
              ),
            ],
          ),
        );

      case _SheetState.idle:
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            // Recently added pantry
            if (_recentPantry.isNotEmpty) ...[
              const Text('Recently Added',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentPantry.map((food) {
                  final already = _selected.contains(food);
                  return GestureDetector(
                    onTap: already ? null : () => _selectByName(food),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: already
                            ? AppColors.primaryAccent.withValues(alpha: 0.15)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: already
                              ? AppColors.primaryAccent.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (already)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.check,
                                  color: AppColors.primaryAccent, size: 12),
                            ),
                          Text(food,
                              style: TextStyle(
                                  color: already
                                      ? AppColors.primaryAccent
                                      : Colors.white70,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
            // Prompt to search
            const Center(
              child: Text('Search above or tap a category',
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Food result row widget — used in search results list
// ---------------------------------------------------------------------------
class _ResultRow extends StatelessWidget {
  final FoodSearchResult result;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResultRow({
    required this.result,
    required this.isSelected,
    required this.onTap,
  });

  Color _sourceColor() => switch (result.source) {
    FoodSource.usda          => const Color(0xFF388E3C), // green
    FoodSource.indianLocal   => const Color(0xFFE65100), // orange
    FoodSource.openfoodfacts => const Color(0xFF1976D2), // blue
    _                        => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isSelected ? null : onTap,
      title: Text(
        result.foodName,
        style: TextStyle(
            color: isSelected ? Colors.white38 : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _sourceColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(result.sourceLabel,
                style: TextStyle(
                    color: _sourceColor(), fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('${result.caloriesPer100g.toInt()} kcal / 100g',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.primaryAccent, size: 20)
          : Icon(Icons.add_circle_outline, color: Colors.white24, size: 20),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
