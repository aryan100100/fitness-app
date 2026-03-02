// [HEALTH APP] — Shimmer Skeleton Loader

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/app_colors.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 60,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cardSurface,
      highlightColor: AppColors.elevatedCard,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A full-screen shimmer skeleton for screens that load AI content.
class FullPageShimmer extends StatelessWidget {
  const FullPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoader(height: 28, width: 200),
          const SizedBox(height: 16),
          const ShimmerLoader(height: 120),
          const SizedBox(height: 12),
          const ShimmerLoader(height: 120),
          const SizedBox(height: 12),
          const ShimmerLoader(height: 120),
          const SizedBox(height: 12),
          const ShimmerLoader(height: 80),
        ],
      ),
    );
  }
}
