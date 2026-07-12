// [HEALTH APP] — Food Log Screen (Feature 4)
// Search interface: tier 0 recents, tier 0 usuals, multi-tier search results.
// Opens pre-focused with the meal type context passed from MealSection.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/food_search_service.dart';
import '../../core/services/streak_service.dart';
import '../../models/food_log_model.dart';
import '../../models/food_search_result.dart';
import '../../models/user_model.dart';
import 'food_detail_sheet.dart';
import 'manual_entry_screen.dart';
import 'photo_estimator_screen.dart';
import 'barcode_scanner_screen.dart';

class FoodLogScreen extends StatefulWidget {
  final String mealType;
  final UserModel user;

  const FoodLogScreen({
    super.key,
    required this.mealType,
    required this.user,
  });

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  final _searchController = TextEditingController();
  final _service = FoodSearchService.instance;

  List<FoodLogModel> _recentFoods = [];
  List<FoodLogModel> _usualFoods  = [];
  List<FoodSearchResult> _results = [];

  bool _isSearching = false;
  bool _hasSearched = false;

  Timer? _debounce;

  String get _mealLabel => switch (widget.mealType) {
    'breakfast' => 'Breakfast',
    'lunch'     => 'Lunch',
    'dinner'    => 'Dinner',
    _           => 'Snacks',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final futures = await Future.wait([
      _service.getRecentFoods(userId),
      _service.getUsualFoods(userId),
    ]);
    if (mounted) {
      setState(() {
        _recentFoods = futures[0];
        _usualFoods  = futures[1];
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? '';
      final results = await _service.search(value.trim(), userId);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    });
  }

  void _openDetailSheet(FoodSearchResult food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FoodDetailSheet(
        food: food,
        mealType: widget.mealType,
        mealLabel: _mealLabel,
        user: widget.user,
      ),
    ).then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _logUsual(FoodLogModel usual) async {
    // Quick-log with usual quantity
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await Supabase.instance.client.from('food_logs').insert({
      'user_id': userId,
      'date': dateStr,
      'meal_type': widget.mealType,
      'food_name': usual.foodName,
      'quantity_g': usual.quantityG,
      'calories': usual.calories,
      'protein_g': usual.proteinG,
      'carbs_g': usual.carbsG,
      'fat_g': usual.fatG,
      'fibre_g': usual.fibreG,
      'food_source': usual.foodSource,
      'is_photo_estimate': false,
    });

    try {
      await StreakService.instance.updateStreak(userId, today);
    } catch (e) {
      debugPrint('[STREAK] Error updating streak from usual log: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${usual.foodName} added to $_mealLabel 👍',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.primaryText)),
          backgroundColor: AppColors.cardSurface,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.primaryText),
        title: Text('Log $_mealLabel', style: AppTextStyles.body),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined,
                color: AppColors.primaryText),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PhotoEstimatorScreen(
                    mealType: widget.mealType, user: widget.user),
              ),
            ).then((_) {
               if (!context.mounted) return;
               Navigator.of(context).pop();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Search foods or scan a photo...',
                hintStyle: AppTextStyles.bodySecondary,
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.secondaryText),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                AppColors.primaryAccent),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppColors.secondaryText),
                        tooltip: 'Scan barcode',
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => BarcodeScannerScreen(
                                mealType: widget.mealType,
                                user: widget.user),
                          ));
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                      ),
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // searching indicator
          if (_isSearching)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 2),
                  Text('Searching USDA + Indian + Open Food Facts...',
                      style: AppTextStyles.caption),
                ],
              ),
            ),

          Expanded(
            child: _hasSearched && _searchController.text.length >= 2
                ? _SearchResults(
                    results: _results,
                    onTap: _openDetailSheet,
                    onNoResults: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ManualEntryScreen(
                              mealType: widget.mealType,
                              user: widget.user,
                              prefillName:
                                  _searchController.text.trim())),
                    ).then((_) {
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    }),
                  )
                : _InitialContent(
                    usualFoods: _usualFoods,
                    recentFoods: _recentFoods,
                    onUsualTap: _logUsual,
                    onRecentTap: (log) {
                      // Convert recent log to FoodSearchResult for detail sheet
                      _openDetailSheet(FoodSearchResult(
                        foodName: log.foodName,
                        servingSizeG: log.quantityG,
                        caloriesPer100g: log.quantityG > 0
                            ? log.calories / log.quantityG * 100
                            : log.calories,
                        proteinPer100g: log.quantityG > 0
                            ? log.proteinG / log.quantityG * 100
                            : log.proteinG,
                        carbsPer100g: log.quantityG > 0
                            ? log.carbsG / log.quantityG * 100
                            : log.carbsG,
                        fatPer100g: log.quantityG > 0
                            ? log.fatG / log.quantityG * 100
                            : log.fatG,
                        fibrePer100g: log.quantityG > 0
                            ? log.fibreG / log.quantityG * 100
                            : log.fibreG,
                        source: FoodSource.recent,
                      ));
                    },
                    onManualTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ManualEntryScreen(
                              mealType: widget.mealType, user: widget.user)),
                    ).then((_) {
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    }),
                  ),
          ),
        ],
      ),
      // Barcode scan FAB — hidden when low pressure mode is active
      floatingActionButton: widget.user.lowPressureMode == true
          ? null
          : FloatingActionButton(
              heroTag: 'barcode_fab',
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.black,
              tooltip: 'Scan barcode',
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BarcodeScannerScreen(
                      mealType: widget.mealType, user: widget.user),
                ));
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Icon(Icons.qr_code_scanner, size: 26),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Initial content — usuals + recents
// ---------------------------------------------------------------------------
class _InitialContent extends StatelessWidget {
  final List<FoodLogModel> usualFoods;
  final List<FoodLogModel> recentFoods;
  final void Function(FoodLogModel) onUsualTap;
  final void Function(FoodLogModel) onRecentTap;
  final VoidCallback onManualTap;

  const _InitialContent({
    required this.usualFoods,
    required this.recentFoods,
    required this.onUsualTap,
    required this.onRecentTap,
    required this.onManualTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (usualFoods.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Your Usuals', style: AppTextStyles.body
              .copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: usualFoods.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final food = usualFoods[i];
                return GestureDetector(
                  onTap: () => onUsualTap(food),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 14,
                            color: AppColors.primaryAccent),
                        const SizedBox(width: 4),
                        Text(food.foodName,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryAccent,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (recentFoods.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Recent Foods', style: AppTextStyles.body
              .copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          ...recentFoods.map((log) => GestureDetector(
                onTap: () => onRecentTap(log),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(log.foodName,
                                    style: AppTextStyles.body
                                        .copyWith(fontSize: 15))),
                              // Barcode indicator for scanned foods
                              if (log.foodSource == 'barcode_scan') ...[  
                                const SizedBox(width: 6),
                                const Icon(Icons.qr_code,
                                    size: 13,
                                    color: AppColors.secondaryText),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text('${log.quantityG.round()}g',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      Text('${log.calories.round()} kcal',
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              )),
        ],
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onManualTap,
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.secondaryText),
              const SizedBox(width: 8),
              Text('Add food manually',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search results list
// ---------------------------------------------------------------------------
class _SearchResults extends StatelessWidget {
  final List<FoodSearchResult> results;
  final void Function(FoodSearchResult) onTap;
  final VoidCallback onNoResults;

  const _SearchResults({
    required this.results,
    required this.onTap,
    required this.onNoResults,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text('No results found', style: AppTextStyles.body),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onNoResults,
              child: Text(
                'Can\'t find this food? Add it manually →',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryAccent),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, _) =>
          Divider(color: AppColors.divider, height: 1),
      itemBuilder: (_, i) {
        final food = results[i];
        final badgeColor = _sourceBadgeColor(food.source);
        final subtitle = food.brand?.isNotEmpty == true
            ? food.brand!
            : food.sourceLabel;
        return GestureDetector(
          onTap: () => onTap(food),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.foodName,
                          style: AppTextStyles.body
                              .copyWith(fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 11)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _MiniPill('P: ${food.proteinPer100g.round()}g',
                              AppColors.proteinBar),
                          const SizedBox(width: 5),
                          _MiniPill('C: ${food.carbsPer100g.round()}g',
                              AppColors.carbBar),
                          const SizedBox(width: 5),
                          _MiniPill('F: ${food.fatPer100g.round()}g',
                              AppColors.fatBar),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${food.caloriesPer100g.round()}',
                        style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('kcal/100g', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    _SourceBadge(food.sourceLabel, badgeColor),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Color mapping helper for source badge
Color _sourceBadgeColor(FoodSource source) => switch (source) {
  FoodSource.usda          => const Color(0xFF388E3C), // green
  FoodSource.indianLocal   => const Color(0xFFE65100), // orange
  FoodSource.openfoodfacts => const Color(0xFF1976D2), // blue
  _                        => const Color(0xFF757575), // grey
};

class _MiniPill extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniPill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: AppTextStyles.caption
              .copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SourceBadge(this.label, [this.color = const Color(0xFF757575)]);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}
