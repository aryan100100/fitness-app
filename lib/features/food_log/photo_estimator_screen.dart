// [HEALTH APP] — Photo Estimator Screen (Feature 4)
// Full AI-powered meal photo estimation flow:
// 1. Image picker → 2. Scanning animation → 3. Editable results → 4. Log

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/streak_service.dart';
import '../../models/user_model.dart';

class PhotoEstimatorScreen extends StatefulWidget {
  final String mealType;
  final UserModel user;

  const PhotoEstimatorScreen({
    super.key,
    required this.mealType,
    required this.user,
  });

  @override
  State<PhotoEstimatorScreen> createState() => _PhotoEstimatorScreenState();
}

class _PhotoEstimatorScreenState extends State<PhotoEstimatorScreen>
    with SingleTickerProviderStateMixin {
  _ScreenState _state = _ScreenState.picking;

  Uint8List? _imageBytes;
  PhotoEstimateResult? _result;
  String? _errorMessage;

  // Editable fields
  late TextEditingController _calCtrl;
  late TextEditingController _protCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  late TextEditingController _fibreCtrl;

  // Scan animation
  late final AnimationController _scanAnim;
  late final Animation<double> _scanLine;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _scanLine = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut));

    _calCtrl   = TextEditingController();
    _protCtrl  = TextEditingController();
    _carbsCtrl = TextEditingController();
    _fatCtrl   = TextEditingController();
    _fibreCtrl = TextEditingController();

    // Open picker immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fibreCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: AppColors.primaryAccent),
            title: Text('Take a photo', style: AppTextStyles.body),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.primaryAccent),
            title: Text('Choose from gallery', style: AppTextStyles.body),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    if (source == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final xFile = await picker.pickImage(source: source, imageQuality: 80);
    if (xFile == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final bytes = await xFile.readAsBytes();
    final mime = xFile.mimeType ?? 'image/jpeg';

    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _state = _ScreenState.analyzing;
    });

    _analyzePhoto(bytes, mime);
  }

  Future<void> _analyzePhoto(Uint8List bytes, String mime) async {
    try {
      final result = await GeminiService.instance.estimateMealFromPhoto(
          bytes.toList(), mime);
      if (!mounted) return;
      _updateResult(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.error;
        _errorMessage =
            'Couldn\'t analyze the photo — try again or log manually.';
      });
    }
  }

  void _updateResult(PhotoEstimateResult result) {
    _result = result;
    _calCtrl.text   = result.totalCalories.round().toString();
    _protCtrl.text  = result.protein.round().toString();
    _carbsCtrl.text = result.carbs.round().toString();
    _fatCtrl.text   = result.fat.round().toString();
    _fibreCtrl.text = result.fibre.round().toString();
    setState(() => _state = _ScreenState.results);
  }

  Future<void> _logMeal() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final cal   = double.tryParse(_calCtrl.text)   ?? 0;
      final prot  = double.tryParse(_protCtrl.text)  ?? 0;
      final carbs = double.tryParse(_carbsCtrl.text) ?? 0;
      final fat   = double.tryParse(_fatCtrl.text)   ?? 0;
      final fibre = double.tryParse(_fibreCtrl.text) ?? 0;

      final foodNames = _result?.foods.take(3).join(', ') ?? 'Photo meal';

      await Supabase.instance.client.from('food_logs').insert({
        'user_id':          userId,
        'date':             dateStr,
        'meal_type':        widget.mealType,
        'food_name':        foodNames,
        'quantity_g':       100.0,
        'calories':         cal,
        'protein_g':        prot,
        'carbs_g':          carbs,
        'fat_g':            fat,
        'fibre_g':          fibre,
        'food_source':      'photo_estimate',
        'is_photo_estimate': true,
      });

      try {
        await StreakService.instance.updateStreak(userId, today);
      } catch (e) {
        debugPrint('[STREAK] Error updating streak from photo log: $e');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t save — please try again',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primaryText)),
            backgroundColor: AppColors.cardSurface,
          ),
        );
      }
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
        title: Text('Photo Estimate', style: AppTextStyles.body),
      ),
      body: switch (_state) {
        _ScreenState.picking   => const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
        _ScreenState.analyzing => _buildAnalyzing(),
        _ScreenState.results   => _buildResults(),
        _ScreenState.error     => _buildError(),
      },
    );
  }

  Widget _buildAnalyzing() {
    return Stack(
      children: [
        // Photo thumbnail
        if (_imageBytes != null)
          Positioned.fill(
            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
          ),
        // Dark overlay
        Positioned.fill(
          child: Container(color: AppColors.background.withOpacity(0.6)),
        ),
        // Scan line animation
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scanLine,
            builder: (_, __) {
              return CustomPaint(
                painter: _ScanLinePainter(progress: _scanLine.value),
              );
            },
          ),
        ),
        // Text
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),
              Text('Analyzing your meal...',
                  style: AppTextStyles.body.copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text('This takes a moment',
                  style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final r = _result!;
    final isLowConf = r.confidence == 'low';
    final isMed = r.confidence == 'medium';
    final confColor = isLowConf
        ? AppColors.destructive
        : (isMed ? AppColors.warning : AppColors.primaryAccent);
    final confLabel = isLowConf
        ? 'Low confidence'
        : (isMed ? 'Medium confidence' : 'High confidence');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo thumbnail
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 16),

          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: confColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: confColor.withOpacity(0.5)),
            ),
            child: Text(confLabel,
                style: AppTextStyles.caption
                    .copyWith(color: confColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),

          // AI detected foods
          Text('AI Detected:', style: AppTextStyles.bodySecondary),
          ...r.foods.map((f) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $f', style: AppTextStyles.body),
              )),

          if (r.portionNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('💡 ${r.portionNotes}',
                style: AppTextStyles.caption),
          ],

          // Warning for low/medium
          if ((isLowConf || isMed) && r.warningMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Text(r.warningMessage!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.warning)),
            ),
          ],

          const SizedBox(height: 20),
          Text('Edit if needed:',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 10),

          // Editable fields
          _EditField(label: 'Calories (kcal)', ctrl: _calCtrl),
          const SizedBox(height: 8),
          _EditField(label: 'Protein (g)', ctrl: _protCtrl),
          const SizedBox(height: 8),
          _EditField(label: 'Carbs (g)', ctrl: _carbsCtrl),
          const SizedBox(height: 8),
          _EditField(label: 'Fat (g)', ctrl: _fatCtrl),
          const SizedBox(height: 8),
          _EditField(label: 'Fibre (g)', ctrl: _fibreCtrl),

          const SizedBox(height: 16),

          // Permanent disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'AI estimates can vary by 10–40% for complex meals. Always review and adjust if needed. This is a convenience tool, not a precise measurement.',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),

          // Log button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _logMeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text('Log This Meal',
                      style: AppTextStyles.buttonLabel
                          .copyWith(color: Colors.black)),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📷', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Couldn\'t analyze the photo',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _state = _ScreenState.picking);
                      _pickImage();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.primaryAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Retry',
                        style: AppTextStyles.captionAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.secondaryText),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Log Manually',
                        style: AppTextStyles.caption),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ScreenState { picking, analyzing, results, error }

// ---------------------------------------------------------------------------
// Scan line painter
// ---------------------------------------------------------------------------
class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..color = AppColors.primaryAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = AppColors.primaryAccent.withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), glowPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Inline editable field for results screen
// ---------------------------------------------------------------------------
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;

  const _EditField({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: AppTextStyles.caption),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style:
                AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              filled: true,
              fillColor: AppColors.cardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
