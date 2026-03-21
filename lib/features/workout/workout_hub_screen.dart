// [HEALTH APP] — Workout Hub Screen
// Entry point for workout tab. Idle state + recent workouts + start session.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/workout_service.dart';
import '../../core/services/workout_session_provider.dart';
import '../../models/workout_model.dart';
import 'active_workout_screen.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  final _service = WorkoutService.instance;
  final _provider = WorkoutSessionProvider.instance;
  final _userId = Supabase.instance.client.auth.currentUser?.id ?? '';

  List<WorkoutModel> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final results = await _service.getWorkouts(
      _userId,
      fromDate: _fmt(from),
      toDate: _fmt(now),
    );
    if (mounted) {
      setState(() {
      _recent = results.take(5).toList();
      _loading = false;
    });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _startWorkout() {
    _provider.startSession();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, _) => const ActiveWorkoutScreen(),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ).then((_) => _loadRecent());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Text('Workout',
                    style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700, fontSize: 22)),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Active session banner
                    if (_provider.hasActiveSession) ...[
                      _ActiveSessionBanner(
                        elapsedLabel: _provider.elapsedLabel,
                        onResume: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ActiveWorkoutScreen()),
                        ).then((_) => _loadRecent()),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Start workout button
                    if (!_provider.hasActiveSession)
                      _StartButton(onTap: _startWorkout),

                    const SizedBox(height: 32),

                    // Recent workouts
                    Text('Recent Workouts',
                        style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),

                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryAccent),
                        ),
                      )
                    else if (_recent.isEmpty)
                      const _EmptyHistory()
                    else
                      ..._recent.map((w) => _WorkoutHistoryCard(workout: w)),

                    // Bottom spacing for nav bar
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SUBWIDGETS
// ---------------------------------------------------------------------------

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded,
                color: Colors.black, size: 24),
            const SizedBox(width: 8),
            Text('Start Empty Workout',
                style: AppTextStyles.body.copyWith(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionBanner extends StatelessWidget {
  final String elapsedLabel;
  final VoidCallback onResume;
  const _ActiveSessionBanner(
      {required this.elapsedLabel, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onResume,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workout in progress',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.primaryAccent,
                          fontWeight: FontWeight.w600)),
                  Text(elapsedLabel, style: AppTextStyles.caption),
                ],
              ),
            ),
            Text('Resume →',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_rounded,
                size: 36, color: AppColors.divider),
            const SizedBox(height: 12),
            Text('No workouts yet',
                style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text('Your history will appear here.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.divider)),
          ],
        ),
      ),
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  final WorkoutModel workout;
  const _WorkoutHistoryCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.elevatedCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                size: 20, color: AppColors.primaryAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${workout.date}  ·  ${workout.durationMinutes}min',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondaryText),
        ],
      ),
    );
  }
}
