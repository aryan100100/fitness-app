// [HEALTH APP] — Welcome Screen (Feature 12)
// First screen shown to unauthenticated users.
// Google Sign In (primary), Apple Sign In (iOS only), Email fallback.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../nav_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'signup_screen.dart';
import 'signin_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _googleLoading = false;
  bool _appleLoading = false;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Route after auth ────────────────────────────────────────────────────────
  Future<void> _handleResult(AuthResult result) async {
    if (!result.success) {
      if (!mounted) return;
      if (result.error != null && result.error != 'Sign-in cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error!),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    if (!mounted) return;
    if (result.isNewUser) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      // Existing user — fetch profile and go to dashboard
      _navigateToDashboard();
    }
  }

  Future<void> _navigateToDashboard() async {
    try {
      final user = await SupabaseService.instance.fetchCurrentUser();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => BottomNavShell(user: user)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (mounted) setState(() => _googleLoading = false);
    await _handleResult(result);
  }

  Future<void> _appleSignIn() async {
    setState(() => _appleLoading = true);
    final result = await AuthService.instance.signInWithApple();
    if (mounted) setState(() => _appleLoading = false);
    await _handleResult(result);
  }

  void _openTerms() => launchUrl(Uri.parse('https://healthapp.example.com/terms'));
  void _openPrivacy() => launchUrl(Uri.parse('https://healthapp.example.com/privacy'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background gradient + logo ────────────────────────────────────
          Positioned.fill(
            child: _buildBackground(context),
          ),
          // ── Bottom panel ─────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildBottomPanel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        SizedBox(
          height: size.height * 0.52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // App logo
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF004D20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'NutriTrack',
                style: AppTextStyles.headingLarge.copyWith(
                  fontSize: 34,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Your personal nutrition coach —\nscience-backed, judgment-free.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary.copyWith(
                      fontSize: 15, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Get started', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          Text(
            'Your data stays private and is only visible to you.',
            style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 24),

          // ── Google Button ─────────────────────────────────────────────────
          _GoogleButton(loading: _googleLoading, onTap: _googleSignIn),
          const SizedBox(height: 12),

          // ── Apple Button (iOS only) ───────────────────────────────────────
          if (Platform.isIOS) ...[
            _AppleButton(loading: _appleLoading, onTap: _appleSignIn),
            const SizedBox(height: 12),
          ],

          // ── Email Button ──────────────────────────────────────────────────
          _EmailButton(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignUpScreen()),
            ),
          ),

          const SizedBox(height: 20),

          // ── Legal text ────────────────────────────────────────────────────
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondaryText, fontSize: 11),
                children: [
                  const TextSpan(
                      text: 'By continuing you agree to our '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                        color: AppColors.primaryAccent,
                        decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = _openTerms,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                        color: AppColors.primaryAccent,
                        decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = _openPrivacy,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Already have account ──────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              ),
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.secondaryText),
                  children: const [
                    TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'Sign in',
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Button ─────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: loading ? null : onTap,
      color: Colors.white,
      child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google "G" logo using coloured squares
                _GoogleLogo(),
                const SizedBox(width: 12),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a simple "G" in Google colours
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue arc (top-right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, 1.57, true, paint);

    // Red arc (bottom-right)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        0, 1.57, true, paint);

    // Yellow arc (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        1.57, 1.57, true, paint);

    // Green arc (top-left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        3.14, 1.57, true, paint);

    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.62, paint);

    // Blue right bar (the horizontal part of G)
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.18, radius, radius * 0.36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Apple Button ──────────────────────────────────────────────────────────────
class _AppleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AppleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: loading ? null : onTap,
      color: Colors.black,
      borderColor: const Color(0xFF333333),
      child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.apple, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Continue with Apple',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Email Button ──────────────────────────────────────────────────────────────
class _EmailButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EmailButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: onTap,
      color: Colors.transparent,
      borderColor: AppColors.primaryAccent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mail_outline_rounded,
              color: AppColors.primaryAccent, size: 20),
          const SizedBox(width: 10),
          Text(
            'Continue with email',
            style: AppTextStyles.body.copyWith(color: AppColors.primaryAccent),
          ),
        ],
      ),
    );
  }
}

// ── Generic auth button ───────────────────────────────────────────────────────
class _AuthButton extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _AuthButton({
    required this.child,
    required this.color,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
