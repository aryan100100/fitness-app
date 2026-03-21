// [HEALTH APP] — Progress Photos Gallery Screen (Feature 9)
// Main gallery view: angle filter chips + vertical timeline sorted newest-first.
// Entry point from Profile tab.

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/progress_photo_service.dart';
import '../../models/progress_photo_model.dart';
import '../../models/user_model.dart';
import 'capture_photo_screen.dart';
import 'comparison_screen.dart';
import 'photo_timeline_entry.dart';

class ProgressPhotosScreen extends StatefulWidget {
  final UserModel user;
  const ProgressPhotosScreen({super.key, required this.user});

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  List<ProgressPhoto> _allPhotos = [];
  bool _isLoading = true;
  String _angleFilter = 'all'; // 'all' | 'front' | 'side' | 'back'

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    final photos = await ProgressPhotoService.instance
        .getAllPhotos(widget.user.id ?? '');
    if (mounted) {
      setState(() {
        _allPhotos = photos;
        _isLoading = false;
      });
    }
  }

  // Group filtered photos by date, newest first
  Map<DateTime, List<ProgressPhoto>> get _groupedPhotos {
    final filtered = _angleFilter == 'all'
        ? _allPhotos
        : _allPhotos.where((p) => p.angle == _angleFilter).toList();

    final Map<DateTime, List<ProgressPhoto>> grouped = {};
    for (final photo in filtered) {
      final dateKey = DateTime(
          photo.photoDate.year, photo.photoDate.month, photo.photoDate.day);
      grouped.putIfAbsent(dateKey, () => []).add(photo);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  Future<void> _navigateToCapture() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CapturePhotoScreen(userId: widget.user.id ?? ''),
      ),
    );
    if (result == true) _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
        title: Text('Progress Photos', style: AppTextStyles.body),
        actions: [
          if (_allPhotos.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComparisonScreen(
                    user: widget.user,
                    allPhotos: _allPhotos,
                  ),
                ),
              ),
              child: Text('Compare',
                  style: AppTextStyles.captionAccent.copyWith(fontSize: 13)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCapture,
        backgroundColor: AppColors.primaryAccent,
        child: const Icon(Icons.add_a_photo, color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : _allPhotos.isEmpty
              ? _EmptyState(onTakePhoto: _navigateToCapture)
              : Column(
                  children: [
                    // Angle filter chips
                    _AngleFilterChips(
                      selected: _angleFilter,
                      onSelect: (a) => setState(() => _angleFilter = a),
                    ),
                    // Timeline
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primaryAccent,
                        backgroundColor: AppColors.cardSurface,
                        onRefresh: _loadPhotos,
                        child: _groupedPhotos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No photos for this angle yet.',
                                  style: TextStyle(color: AppColors.secondaryText),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                itemCount: _groupedPhotos.length,
                                itemBuilder: (_, i) {
                                  final date =
                                      _groupedPhotos.keys.elementAt(i);
                                  final photos = _groupedPhotos[date]!;
                                  return PhotoTimelineEntry(
                                    date: date,
                                    photos: photos,
                                    onPhotoDeleted: _loadPhotos,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Angle filter chips
// ─────────────────────────────────────────────────────────────────────────────
class _AngleFilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _AngleFilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = ['all', 'front', 'side', 'back'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: options.map((o) {
          final isActive = o == selected;
          final label = o[0].toUpperCase() + o.substring(1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryAccent
                      : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.black : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onTakePhoto;
  const _EmptyState({required this.onTakePhoto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined,
                size: 56, color: AppColors.secondaryText),
            const SizedBox(height: 20),
            Text('No photos yet', style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            Text(
              'Take your first progress photo to start building a visual record of your journey.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.add_a_photo, color: Colors.black),
              label: Text('Take your first progress photo',
                  style: AppTextStyles.buttonLabel.copyWith(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
