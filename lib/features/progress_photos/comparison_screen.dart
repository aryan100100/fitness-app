// [HEALTH APP] — Comparison Screen (Feature 9)
// Side-by-side STATIC view only. No slider/swipe overlay (research-backed).
// No AI analysis — photos shown as stored, nothing more.
// Includes 14-day proximity warning and one-time frequency protection note.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/progress_photo_service.dart';
import '../../models/progress_photo_model.dart';
import '../../models/user_model.dart';

class ComparisonScreen extends StatefulWidget {
  final UserModel user;
  final List<ProgressPhoto> allPhotos;

  const ComparisonScreen({
    super.key,
    required this.user,
    required this.allPhotos,
  });

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late List<DateTime> _availableDates;
  late DateTime _earlierDate;
  late DateTime _laterDate;
  String _selectedAngle = 'front';

  String? _earlierUrl;
  String? _laterUrl;
  bool _loadingUrls = false;

  bool _showFrequencyNote = false;
  static const _freqNoteKey = 'progress_photo_freq_dismissed';

  @override
  void initState() {
    super.initState();
    // Derive unique sorted dates
    _availableDates = widget.allPhotos
        .map((p) =>
            DateTime(p.photoDate.year, p.photoDate.month, p.photoDate.day))
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (_availableDates.length >= 2) {
      _earlierDate = _availableDates.first;
      _laterDate = _availableDates.last;
    } else if (_availableDates.length == 1) {
      _earlierDate = _availableDates.first;
      _laterDate = _availableDates.first;
    } else {
      final now = DateTime.now();
      _earlierDate = now;
      _laterDate = now;
    }

    _logAndCheckFrequency();
    _loadPhotos();
  }

  Future<void> _logAndCheckFrequency() async {
    final userId = widget.user.id ?? '';
    await ProgressPhotoService.instance.logComparisonView(userId);
    final shouldWarn =
        await ProgressPhotoService.instance.shouldShowFrequencyWarning(userId);

    if (!shouldWarn) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_freqNoteKey) ?? false;
    if (!dismissed && mounted) {
      setState(() => _showFrequencyNote = true);
    }
  }

  Future<void> _dismissFrequencyNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freqNoteKey, true);
    if (mounted) setState(() => _showFrequencyNote = false);
  }

  // Find the best matching photo for a date + angle. Returns null if not found.
  ProgressPhoto? _findPhoto(DateTime date, String angle) {
    try {
      return widget.allPhotos.firstWhere(
        (p) =>
            p.photoDate.year == date.year &&
            p.photoDate.month == date.month &&
            p.photoDate.day == date.day &&
            p.angle == angle,
      );
    } catch (_) {
      return null;
    }
  }

  // Return angles where BOTH selected dates have a photo
  List<String> get _validAngles {
    return ['front', 'side', 'back'].where((a) {
      return _findPhoto(_earlierDate, a) != null &&
          _findPhoto(_laterDate, a) != null;
    }).toList();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loadingUrls = true;
      _earlierUrl = null;
      _laterUrl = null;
    });

    final earlierPhoto = _findPhoto(_earlierDate, _selectedAngle);
    final laterPhoto = _findPhoto(_laterDate, _selectedAngle);

    final results = await Future.wait([
      earlierPhoto != null
          ? ProgressPhotoService.instance.getSignedUrl(earlierPhoto.storagePath)
          : Future<String?>.value(null),
      laterPhoto != null
          ? ProgressPhotoService.instance.getSignedUrl(laterPhoto.storagePath)
          : Future<String?>.value(null),
    ]);

    if (mounted) {
      setState(() {
        _earlierUrl = results[0];
        _laterUrl = results[1];
        _loadingUrls = false;
      });
    }
  }

  bool get _showProximityWarning {
    final diff = _laterDate.difference(_earlierDate).inDays.abs();
    return diff < 14;
  }

  Future<void> _pickDate(bool isEarlier) async {
    final initial = isEarlier ? _earlierDate : _laterDate;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _DatePickerDialog(
        initialDate: initial,
        availableDates: _availableDates,
        title: isEarlier ? 'Earlier date' : 'Later date',
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isEarlier) {
        _earlierDate = picked;
      } else {
        _laterDate = picked;
      }
      // Auto-select valid angle after date change
      final valid = _validAngles;
      if (!valid.contains(_selectedAngle) && valid.isNotEmpty) {
        _selectedAngle = valid.first;
      }
    });
    _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
        title: Text('Compare Photos', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frequency protection note
            if (_showFrequencyNote)
              _FrequencyNote(onDismiss: _dismissFrequencyNote),

            // Date pickers row
            Row(
              children: [
                Expanded(
                  child: _DatePickerTile(
                    label: 'Earlier',
                    date: _earlierDate,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerTile(
                    label: 'Later',
                    date: _laterDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 14-day proximity warning
            if (_showProximityWarning)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'These photos are less than 2 weeks apart — changes may be too subtle to see and mostly reflect lighting or water. Try comparing photos at least 4-8 weeks apart for more meaningful differences.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),

            // Photo panels
            if (_loadingUrls)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AppColors.primaryAccent),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _PhotoPanel(
                          url: _earlierUrl,
                          date: _earlierDate,
                          angle: _selectedAngle)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _PhotoPanel(
                          url: _laterUrl,
                          date: _laterDate,
                          angle: _selectedAngle)),
                ],
              ),

            const SizedBox(height: 20),

            // Angle selector — only valid angles
            if (_validAngles.isNotEmpty) ...[
              Text('Angle', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Row(
                children: _validAngles.map((a) {
                  final isActive = a == _selectedAngle;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        if (a != _selectedAngle) {
                          setState(() => _selectedAngle = a);
                          _loadPhotos();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primaryAccent
                              : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          a[0].toUpperCase() + a.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isActive
                                ? Colors.black
                                : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No matching angles for both selected dates. Change one date or take more photos.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerTile(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  DateFormat('d MMM yyyy').format(date),
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPanel extends StatelessWidget {
  final String? url;
  final DateTime date;
  final String angle;

  const _PhotoPanel(
      {required this.url, required this.date, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 0.72,
            child: url != null
                ? Image.network(url!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.cardSurface,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppColors.secondaryText, size: 36),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          DateFormat('d MMM').format(date),
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _FrequencyNote extends StatelessWidget {
  final VoidCallback onDismiss;
  const _FrequencyNote({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_outline,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "We noticed you've been checking your photos quite often. Progress photos are most useful when checked every few weeks — checking more often can sometimes feel discouraging. Your weight trend and streak are also great ways to see your progress.",
              style: AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                size: 16, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker dialog — shows available dates as a list
// ─────────────────────────────────────────────────────────────────────────────
class _DatePickerDialog extends StatelessWidget {
  final DateTime initialDate;
  final List<DateTime> availableDates;
  final String title;

  const _DatePickerDialog({
    required this.initialDate,
    required this.availableDates,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardSurface,
      title: Text(title, style: AppTextStyles.body),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: availableDates.length,
          separatorBuilder: (_, _) =>
              const Divider(color: AppColors.divider, height: 1),
          itemBuilder: (_, i) {
            final d = availableDates[i];
            final isSelected = d == initialDate;
            return ListTile(
              dense: true,
              title: Text(
                DateFormat('d MMMM yyyy').format(d),
                style: AppTextStyles.body.copyWith(
                  color: isSelected
                      ? AppColors.primaryAccent
                      : AppColors.primaryText,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check,
                      color: AppColors.primaryAccent, size: 18)
                  : null,
              onTap: () => Navigator.pop(context, d),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppTextStyles.captionAccent),
        ),
      ],
    );
  }
}
