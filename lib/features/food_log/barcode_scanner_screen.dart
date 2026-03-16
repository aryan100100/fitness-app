// [HEALTH APP] — Barcode Scanner Screen (Feature 10)
// Full-screen camera + ML Kit barcode detection via mobile_scanner.
// On-device only — no images or barcode values sent to any server for decoding.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/barcode_service.dart';
import '../../models/barcode_product_model.dart';
import '../../models/user_model.dart';
import 'barcode_result_screen.dart';
import 'barcode_not_found_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String mealType;
  final UserModel user;

  const BarcodeScannerScreen({
    super.key,
    required this.mealType,
    required this.user,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _torchEnabled = false;
  bool _isLookingUp = false;
  bool _scanned = false;
  String _guidanceText = 'Point camera at the barcode';
  DateTime? _lastNoDetection;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Update guidance text after 3 seconds of no barcode
    Future.delayed(const Duration(seconds: 3), _checkGuidance);
  }

  void _checkGuidance() {
    if (!mounted || _scanned) return;
    if (mounted) {
      setState(() =>
          _guidanceText = 'Move closer or improve lighting');
    }
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_scanned || _isLookingUp) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    _scanned = true;
    await _scannerController.stop();
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _guidanceText = 'Found it — looking up product...';
        _isLookingUp = true;
      });
    }

    await _lookupAndNavigate(rawValue);
  }

  Future<void> _lookupAndNavigate(String barcode) async {
    final result = await BarcodeService.instance.lookupBarcode(
      barcode,
      userId: widget.user.id ?? '',
    );

    if (!mounted) return;

    await BarcodeService.instance.logScan(
      widget.user.id ?? '',
      barcode,
      result.source,
    );

    if (result.found && result.product != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BarcodeResultScreen(
            product: result.product!,
            mealType: widget.mealType,
            user: widget.user,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BarcodeNotFoundScreen(
            barcode: barcode,
            mealType: widget.mealType,
            user: widget.user,
          ),
        ),
      );
    }
  }

  Future<void> _showManualEntry() async {
    await _scannerController.stop();
    if (!mounted) return;

    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Enter barcode manually', style: AppTextStyles.body),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'e.g. 8901058851427',
            hintStyle: AppTextStyles.caption,
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: const UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primaryAccent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.captionAccent),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) Navigator.pop(context, val);
            },
            child:
                Text('Look up', style: AppTextStyles.captionAccent),
          ),
        ],
      ),
    );

    if (entered != null && entered.isNotEmpty && mounted) {
      setState(() {
        _isLookingUp = true;
        _guidanceText = 'Found it — looking up product...';
      });
      await _lookupAndNavigate(entered);
    } else {
      await _scannerController.start();
    }
  }

  void _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (mounted) setState(() => _torchEnabled = !_torchEnabled);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera feed ───────────────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            ),
          ),

          // ── Dark overlay with scanning window cut-out ─────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _ScanOverlayPainter(),
            ),
          ),

          // ── Animated corner brackets ──────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Opacity(
                opacity: _pulseAnimation.value,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _CornerBracketPainter(
                      color: _isLookingUp
                          ? AppColors.primaryAccent
                          : AppColors.primaryAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Guidance text ─────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.38,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _guidanceText,
                key: ValueKey(_guidanceText),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    shadows: [
                      const Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 1),
                          blurRadius: 6)
                    ]),
              ),
            ),
          ),

          // ── Close button (top left) ───────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 22),
              ),
            ),
          ),

          // ── Torch button (top right) ──────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: _toggleTorch,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _torchEnabled
                      ? AppColors.primaryAccent
                      : Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _torchEnabled ? Icons.flashlight_on : Icons.flashlight_off,
                  color: _torchEnabled ? Colors.black : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // ── Manual entry button (bottom) ──────────────────────────────────
          if (!_isLookingUp)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 40,
              child: Center(
                child: TextButton(
                  onPressed: _showManualEntry,
                  child: Text(
                    'Enter barcode manually',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),

          // ── Looking-up loading overlay ────────────────────────────────────
          if (_isLookingUp)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Semi-transparent dark overlay with a clear 240×240 scanning window.
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final cx = size.width / 2;
    final cy = size.height / 2;
    const w = 240.0;
    const h = 240.0;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);

    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final window = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));
    canvas.drawPath(
        Path.combine(PathOperation.difference, full, window), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Corner brackets (L-shaped lines) at the four corners of the scan window.
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  const _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 28.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter old) =>
      old.color != color;
}
