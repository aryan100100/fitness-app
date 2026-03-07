// [HEALTH APP] — Food Input Sheet (Bottom Sheet)
// Lets user add foods to their today-list from 3 sources:
// 1. Hardcoded common pantry staples
// 2. Indian foods local list (pulled from a curated subset)
// 3. Recent user food_logs (fetched once on open)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';

const List<String> _commonPantryItems = [
  'Eggs', 'Bread', 'Rice', 'Dal', 'Chicken', 'Milk', 'Curd', 'Paneer',
  'Oats', 'Banana', 'Apple', 'Orange', 'Potato', 'Onion', 'Tomato',
  'Spinach', 'Carrot', 'Cucumber', 'Cheese', 'Butter', 'Ghee', 'Oil',
  'Wheat flour', 'Maida', 'Poha', 'Upma', 'Idli', 'Dosa', 'Sambar',
  'Peanut butter', 'Almonds', 'Walnuts', 'Cashews', 'Raisins',
  'Tuna', 'Salmon', 'Whey protein', 'Soy milk', 'Tofu',
  'Lentils', 'Chickpeas', 'Kidney beans', 'Black beans', 'Peas',
  'Sweet potato', 'Pumpkin', 'Broccoli', 'Cauliflower', 'Cabbage',
  'Green beans', 'Capsicum', 'Garlic', 'Ginger', 'Lemon', 'Lime',
  'Honey', 'Jaggery', 'Sugar', 'Salt', 'Pepper', 'Cumin', 'Coriander',
  'Turmeric', 'Chilli powder', 'Garam masala', 'Mustard seeds',
  'Semolina', 'Cornflakes', 'Muesli', 'Granola', 'Quinoa',
  'Whole wheat pasta', 'White pasta', 'Noodles', 'Maggi',
  'Coconut milk', 'Coconut', 'Groundnut oil', 'Sunflower oil',
  'Flaxseeds', 'Chia seeds', 'Sesame seeds', 'Sunflower seeds',
  'Greek yoghurt', 'Skimmed milk', 'Full fat milk', 'Cream',
  'Boiled chickpeas', 'Sprouts', 'Moong dal', 'Masoor dal',
  'Chana dal', 'Urad dal', 'Rajma', 'Soya chunks',
  'Besan', 'Ragi', 'Bajra', 'Jowar', 'Amaranth',
  'Mango', 'Papaya', 'Pineapple', 'Watermelon', 'Grapes', 'Pomegranate',
  'Dates', 'Figs', 'Prunes', 'Pear', 'Peach',
];

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
  List<String> _suggestions = [];
  List<String> _recentFoods = [];
  Timer? _debounce;
  bool _loadingRecents = true;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _textCtrl = TextEditingController();
    _textCtrl.addListener(_onTextChanged);
    _loadRecentFoods();
    _updateSuggestions('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFoods() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      if (userId.isEmpty) return;
      final data = await Supabase.instance.client
          .from('food_logs')
          .select('food_name')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      final names = (data as List)
          .map((e) => e['food_name'] as String)
          .toSet()
          .toList();
      if (mounted) {
        setState(() {
          _recentFoods = names;
          _loadingRecents = false;
        });
        _updateSuggestions(_textCtrl.text);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecents = false);
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _updateSuggestions(_textCtrl.text);
    });
  }

  void _updateSuggestions(String query) {
    final q = query.toLowerCase().trim();
    final all = [
      ..._recentFoods,
      ..._commonPantryItems,
    ];
    // Deduplicate, case-insensitive
    final seen = <String>{};
    final deduped = <String>[];
    for (final item in all) {
      final key = item.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        deduped.add(item);
      }
    }
    final filtered = q.isEmpty
        ? deduped
        : deduped.where((s) => s.toLowerCase().contains(q)).toList();
    if (mounted) setState(() => _suggestions = filtered.take(30).toList());
  }

  void _addFood(String food) {
    final trimmed = food.trim();
    if (trimmed.isEmpty || _selected.contains(trimmed)) return;
    setState(() {
      _selected.add(trimmed);
      _textCtrl.clear();
    });
  }

  void _removeFood(String food) {
    setState(() => _selected.remove(food));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text('What do you have available?',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              // Search input
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _textCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a food or ingredient...',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primaryAccent),
                      onPressed: () => _addFood(_textCtrl.text),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: _addFood,
                ),
              ),
              // Selected chips
              if (_selected.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: _selected
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(
                                  f.length > 15
                                      ? '${f.substring(0, 15)}…'
                                      : f,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor:
                                    AppColors.primaryAccent.withValues(alpha: 0.2),
                                deleteIcon: const Icon(Icons.close,
                                    size: 14, color: Colors.white54),
                                onDeleted: () => _removeFood(f),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              const Divider(color: Colors.white12, height: 1),
              // Suggestions
              Expanded(
                child: _loadingRecents
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _suggestions.length,
                        itemBuilder: (_, i) {
                          final food = _suggestions[i];
                          final already = _selected.contains(food);
                          return ListTile(
                            dense: true,
                            title: Text(food,
                                style: TextStyle(
                                    color: already
                                        ? Colors.white38
                                        : Colors.white,
                                    fontSize: 14)),
                            trailing: already
                                ? const Icon(Icons.check,
                                    color: AppColors.primaryAccent, size: 16)
                                : null,
                            onTap: already ? null : () => _addFood(food),
                          );
                        },
                      ),
              ),
              // Done button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Done  (${_selected.length} added)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
