// [HEALTH APP] — Capture Photo Screen (Feature 9)
// Handles photo capture with angle selection, pose guide silhouettes, and upload.
// NO AI analysis — photos are stored only, no automated feedback.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/progress_photo_service.dart';

class CapturePhotoScreen extends StatefulWidget {
  final String userId;
  final String? initialAngle; // pre-select an angle if coming from gallery

  const CapturePhotoScreen({
    super.key,
    required this.userId,
    this.initialAngle,
  });

  @override
  State<CapturePhotoScreen> createState() => _CapturePhotoScreenState();
}

class _CapturePhotoScreenState extends State<CapturePhotoScreen> {
  String _selectedAngle = 'front';
  File? _selectedFile;
  bool _isUploading = false;

  final _picker = ImagePicker();
  final DateTime _today = DateTime.now();

  static const _angles = ['front', 'side', 'back'];

  @override
  void initState() {
    super.initState();
    if (widget.initialAngle != null && _angles.contains(widget.initialAngle)) {
      _selectedAngle = widget.initialAngle!;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1600,
      );
      if (picked != null && mounted) {
        setState(() => _selectedFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access photos: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _confirmUpload() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);
    try {
      await ProgressPhotoService.instance.savePhoto(
        widget.userId,
        _today,
        _selectedAngle,
        _selectedFile!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved ✅',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save photo. Please try again.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Progress Photo', style: AppTextStyles.body),
            Text(
              DateFormat('d MMMM yyyy').format(_today),
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      body: _selectedFile == null
          ? _buildPickerView()
          : _buildPreviewView(),
    );
  }

  // ── Picker view: angle tabs, pose guide, tips, source buttons ────────────
  Widget _buildPickerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Angle selector
          _AngleTabRow(
            selected: _selectedAngle,
            onSelect: (a) => setState(() => _selectedAngle = a),
          ),
          const SizedBox(height: 24),

          // Pose guide silhouette
          Center(
            child: _PoseGuide(angle: _selectedAngle),
          ),
          const SizedBox(height: 20),

          // Tip chips
          _TipChips(),
          const SizedBox(height: 32),

          // Source buttons
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.black),
              label: Text('Take photo',
                  style: AppTextStyles.buttonLabel.copyWith(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primaryAccent),
              label: Text('Choose from library',
                  style: AppTextStyles.buttonLabel
                      .copyWith(color: AppColors.primaryAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Preview view: photo + silhouette overlay, confirm/retake ─────────────
  Widget _buildPreviewView() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(_selectedFile!, fit: BoxFit.cover),
              // Silhouette overlay — semi-transparent for reference
              Opacity(
                opacity: 0.35,
                child: Center(child: _PoseGuide(angle: _selectedAngle, forOverlay: true)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.background,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUploading ? null : () => setState(() => _selectedFile = null),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Retake', style: AppTextStyles.buttonLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _confirmUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text('Use this photo',
                          style: AppTextStyles.buttonLabel
                              .copyWith(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Angle tab row
// ─────────────────────────────────────────────────────────────────────────────
class _AngleTabRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _AngleTabRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const angles = ['front', 'side', 'back'];
    return Row(
      children: angles.map((a) {
        final isActive = a == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryAccent
                    : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  a[0].toUpperCase() + a.substring(1),
                  style: AppTextStyles.caption.copyWith(
                    color: isActive ? Colors.black : AppColors.secondaryText,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pose guide — CustomPaint silhouette for each angle
// ─────────────────────────────────────────────────────────────────────────────
class _PoseGuide extends StatelessWidget {
  final String angle;
  final bool forOverlay;

  const _PoseGuide({required this.angle, this.forOverlay = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: forOverlay ? double.infinity : 180,
      height: forOverlay ? double.infinity : 300,
      child: CustomPaint(
        painter: _SilhouettePainter(angle: angle),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  final String angle;
  const _SilhouettePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = AppColors.primaryAccent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.height / 300;

    // Head
    canvas.drawCircle(Offset(cx, cy - 110 * scale), 20 * scale, paint);
    canvas.drawCircle(Offset(cx, cy - 110 * scale), 20 * scale, outlinePaint);

    if (angle == 'side') {
      // Simplified side-profile body path
      final body = Path()
        ..moveTo(cx - 8 * scale, cy - 90 * scale)
        ..lineTo(cx + 18 * scale, cy - 80 * scale)  // chest
        ..lineTo(cx + 20 * scale, cy - 40 * scale)  // abdomen
        ..lineTo(cx + 14 * scale, cy)               // hip
        ..lineTo(cx + 12 * scale, cy + 60 * scale)  // thigh
        ..lineTo(cx + 10 * scale, cy + 120 * scale) // shin
        ..lineTo(cx - 2 * scale, cy + 120 * scale)  // foot
        ..lineTo(cx - 8 * scale, cy + 60 * scale)
        ..lineTo(cx - 6 * scale, cy)
        ..lineTo(cx - 12 * scale, cy - 40 * scale)
        ..lineTo(cx - 8 * scale, cy - 90 * scale)
        ..close();
      canvas.drawPath(body, paint);
      canvas.drawPath(body, outlinePaint);

      // Arm (in front, since profile)
      final arm = Path()
        ..moveTo(cx + 18 * scale, cy - 80 * scale)
        ..lineTo(cx + 30 * scale, cy - 20 * scale)
        ..lineTo(cx + 24 * scale, cy + 30 * scale)
        ..lineTo(cx + 16 * scale, cy + 30 * scale)
        ..lineTo(cx + 22 * scale, cy - 20 * scale)
        ..lineTo(cx + 14 * scale, cy - 75 * scale)
        ..close();
      canvas.drawPath(arm, paint);
      canvas.drawPath(arm, outlinePaint);
    } else {
      // Front or Back — symmetric body
      final body = Path()
        ..moveTo(cx - 22 * scale, cy - 88 * scale)  // shoulder L
        ..lineTo(cx + 22 * scale, cy - 88 * scale)  // shoulder R
        ..lineTo(cx + 18 * scale, cy - 40 * scale)  // waist R
        ..lineTo(cx + 22 * scale, cy)               // hip R
        ..lineTo(cx + 14 * scale, cy + 120 * scale) // foot R
        ..lineTo(cx + 4 * scale, cy + 120 * scale)
        ..lineTo(cx + 10 * scale, cy)
        ..lineTo(cx, cy - 20 * scale)               // centre waist
        ..lineTo(cx - 10 * scale, cy)
        ..lineTo(cx - 4 * scale, cy + 120 * scale)
        ..lineTo(cx - 14 * scale, cy + 120 * scale) // foot L
        ..lineTo(cx - 22 * scale, cy)               // hip L
        ..lineTo(cx - 18 * scale, cy - 40 * scale)  // waist L
        ..lineTo(cx - 22 * scale, cy - 88 * scale)
        ..close();
      canvas.drawPath(body, paint);
      canvas.drawPath(body, outlinePaint);

      // Arms
      for (final side in [-1.0, 1.0]) {
        final arm = Path()
          ..moveTo(cx + side * 22 * scale, cy - 88 * scale)
          ..lineTo(cx + side * 36 * scale, cy - 20 * scale)
          ..lineTo(cx + side * 28 * scale, cy + 40 * scale)
          ..lineTo(cx + side * 20 * scale, cy + 40 * scale)
          ..lineTo(cx + side * 28 * scale, cy - 20 * scale)
          ..lineTo(cx + side * 14 * scale, cy - 82 * scale)
          ..close();
        canvas.drawPath(arm, paint);
        canvas.drawPath(arm, outlinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => old.angle != angle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tip chips
// ─────────────────────────────────────────────────────────────────────────────
class _TipChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tips = [
      'Morning before eating = most consistent',
      'Same lighting & clothing reduces variation',
      'Consistent distance & background helps',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tips
          .map((t) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(t,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 11)),
              ))
          .toList(),
    );
  }
}
