// [HEALTH APP] — Pantry Chip Row Widget
// Horizontal scrollable row of food chips with remove and add buttons.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PantryChipRow extends StatelessWidget {
  final List<String> foods;
  final void Function(String food) onRemove;
  final VoidCallback onAdd;

  const PantryChipRow({
    super.key,
    required this.foods,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...foods.map((food) {
            final label = food.length > 15 ? '${food.substring(0, 15)}…' : food;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                backgroundColor: const Color(0xFF2A2A2A),
                side: const BorderSide(color: Colors.white12),
                deleteIcon:
                    const Icon(Icons.close, size: 14, color: Colors.white38),
                onDeleted: () => onRemove(food),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          }),
          // ＋ Add chip
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryAccent, width: 1.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add,
                      size: 14, color: AppColors.primaryAccent),
                  const SizedBox(width: 4),
                  Text('Add',
                      style: TextStyle(
                          color: AppColors.primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
