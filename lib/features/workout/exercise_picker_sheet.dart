// [HEALTH APP] — Exercise Picker Bottom Sheet
// Hevy-style: search + category filter chips + preset list + custom entry.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/exercise_preset_model.dart';

class ExercisePickerSheet extends StatefulWidget {
  final void Function(ExercisePreset) onSelected;

  const ExercisePickerSheet({super.key, required this.onSelected});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';
  List<ExercisePreset> _results = ExerciseLibrary.all;

  static const _categories = [
    ('all', 'All'),
    ('chest', 'Chest'),
    ('back', 'Back'),
    ('legs', 'Legs'),
    ('shoulders', 'Shoulders'),
    ('arms', 'Arms'),
    ('core', 'Core'),
    ('cardio', 'Cardio'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchCtrl.text;
    final bySearch = ExerciseLibrary.search(query);
    setState(() {
      _results = _selectedCategory == 'all'
          ? bySearch
          : bySearch.where((e) => e.category == _selectedCategory).toList();
    });
  }

  void _addCustom() {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onSelected(ExercisePreset(
      name: name,
      category: _selectedCategory == 'all' ? 'other' : _selectedCategory,
      isCardio: _selectedCategory == 'cardio',
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Add Exercise',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _filter(),
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.secondaryText, size: 20),
                    filled: true,
                    fillColor: AppColors.cardSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Category chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final selected = _selectedCategory == cat.$1;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat.$1);
                        _filter();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryAccent
                              : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat.$2,
                          style: AppTextStyles.caption.copyWith(
                            color: selected ? Colors.black : AppColors.secondaryText,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider, height: 1),

              // Exercise list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _results.length + 1, // +1 for custom create
                  itemBuilder: (context, i) {
                    // Custom create row at top
                    if (i == 0) {
                      final query = _searchCtrl.text.trim();
                      if (query.isEmpty) return const SizedBox.shrink();
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: AppColors.primaryAccent, size: 20),
                        ),
                        title: Text('Create "$query"',
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.primaryAccent)),
                        subtitle: Text('Custom exercise',
                            style: AppTextStyles.caption),
                        onTap: _addCustom,
                      );
                    }

                    final preset = _results[i - 1];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 2),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            _categoryIcon(preset.category),
                            size: 18,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                      title: Text(preset.name, style: AppTextStyles.body),
                      subtitle: Text(
                        _capitalize(preset.category),
                        style: AppTextStyles.caption,
                      ),
                      onTap: () {
                        widget.onSelected(preset);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String cat) {
    return switch (cat) {
      'chest' => Icons.fitness_center_rounded,
      'back' => Icons.accessibility_new_rounded,
      'legs' => Icons.directions_walk_rounded,
      'shoulders' => Icons.sports_gymnastics_rounded,
      'arms' => Icons.front_hand_rounded,
      'core' => Icons.circle_outlined,
      'cardio' => Icons.directions_run_rounded,
      _ => Icons.bolt_rounded,
    };
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
