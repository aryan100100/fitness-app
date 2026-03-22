// [HEALTH APP] — Bottom Navigation Shell
// Persistent 5-tab nav bar. Uses IndexedStack to preserve state across tabs.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../models/user_model.dart';
import 'dashboard/dashboard_screen.dart';
import 'dashboard/dashboard_provider.dart';
import 'diet_planner/diet_planner_screen.dart';
import 'food_log/food_log_screen.dart';
import 'profile/profile_screen.dart';
import 'workout/workout_hub_screen.dart';

class BottomNavShell extends StatefulWidget {
  final UserModel user;
  final int initialIndex;

  const BottomNavShell({
    super.key,
    required this.user,
    this.initialIndex = 0,
  });

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    // Tab 1 (Log) opens food log as a full-screen modal so we can
    // refresh the dashboard on return. It doesn't live in IndexedStack.
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FoodLogScreen(
            mealType: _getMealType(),
            user: widget.user,
          ),
        ),
      ).then((_) {
        if (!mounted) return;
        // Refresh dashboard after logging
        final provider = context.read<DashboardProvider>();
        provider.refresh(widget.user);
      });
      return;
    }
    setState(() => _currentIndex = index);
  }

  /// Choose the meal type heuristic based on time of day
  String _getMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 20) return 'dinner';
    return 'snack';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true, // Allow body content to flow under translucent nav bar
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0 — Dashboard
            DashboardScreen(user: widget.user),
            // Tab 1 — Log (placeholder — opened as modal via _onTabTapped)
            _PlaceholderTab(label: 'Food Log', icon: ''),
            // Tab 2 — AI Plan
            DietPlannerScreen(user: widget.user),
            // Tab 3 — Workouts
            const WorkoutHubScreen(),
            // Tab 4 — Profile
            ProfileScreen(user: widget.user),
          ],
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface.withValues(alpha: 0.75),
                border: const Border(
                  top: BorderSide(color: AppColors.subtleBorder, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        index: 0,
                        currentIndex: _currentIndex,
                        onTap: _onTabTapped,
                      ),
                      _NavItem(
                        icon: Icons.restaurant_rounded,
                        label: 'Log',
                        index: 1,
                        currentIndex: _currentIndex,
                        onTap: _onTabTapped,
                      ),
                      _NavItem(
                        icon: Icons.smart_toy_rounded,
                        label: 'Plan',
                        index: 2,
                        currentIndex: _currentIndex,
                        onTap: _onTabTapped,
                      ),
                      _NavItem(
                        icon: Icons.fitness_center_rounded,
                        label: 'Workout',
                        index: 3,
                        currentIndex: _currentIndex,
                        onTap: _onTabTapped,
                      ),
                      _NavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        index: 4,
                        currentIndex: _currentIndex,
                        onTap: _onTabTapped,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final color =
        isSelected ? AppColors.primaryAccent : AppColors.secondaryText;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                  color: color, 
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  final String icon;
  const _PlaceholderTab({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(label, style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            Text('Coming soon', style: AppTextStyles.bodySecondary),
          ],
        ),
      ),
    );
  }
}
