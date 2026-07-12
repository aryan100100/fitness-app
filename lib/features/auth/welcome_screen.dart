// [HEALTH APP] — Welcome Screen (Feature 12)
// TEMP: Simplified to email/password only for internal testing.
// Google + Apple sign-in code is commented out below — restore by:
//   1. Uncommenting the Google/Apple sections in _buildBottomPanel()
//   2. Uncommenting the _googleSignIn() and _appleSignIn() methods
//   3. Re-adding the Google/Apple button calls in _buildBottomPanel()

// ignore_for_file: unused_import
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../nav_shell.dart';
import '../onboarding/onboarding_screen.dart';

// TEMP: Google/Apple auth disabled for testing — see comment at top of file
// import 'signup_screen.dart';
// import 'signin_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Form mode: sign-in (false) or sign-up (true) ─────────────────────────
  bool _isSignUp = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  bool _emailConfirmationPending = false;

  // ── Entrance animation ─────────────────────────────────────────────────────
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // TEMP: Google/Apple loading states disabled — restore when providers configured
  // bool _googleLoading = false;
  // bool _appleLoading = false;

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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Route after auth ───────────────────────────────────────────────────────
  Future<void> _handleResult(AuthResult result) async {
    if (!result.success) {
      if (!mounted) return;
      if (result.error != null && result.error != 'Sign-in cancelled') {
        final err = result.error!;
        // Route error to the most relevant field
        if (err.toLowerCase().contains('password') ||
            err.toLowerCase().contains('credentials')) {
          setState(() => _passwordError = err);
        } else if (err.toLowerCase().contains('email')) {
          setState(() => _emailError = err);
        } else {
          setState(() => _generalError = err);
        }
      }
      return;
    }

    if (!mounted) return;
    if (result.isNewUser) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } else {
      _navigateToDashboard();
    }
  }

  Future<void> _navigateToDashboard() async {
    try {
      final user = await SupabaseService.instance.fetchCurrentUser();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => BottomNavShell(user: user)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  // TEMP: Google/Apple sign-in methods disabled — restore when providers configured
  //
  // Future<void> _googleSignIn() async {
  //   setState(() => _googleLoading = true);
  //   final result = await AuthService.instance.signInWithGoogle();
  //   if (mounted) setState(() => _googleLoading = false);
  //   await _handleResult(result);
  // }
  //
  // Future<void> _appleSignIn() async {
  //   setState(() => _appleLoading = true);
  //   final result = await AuthService.instance.signInWithApple();
  //   if (mounted) setState(() => _appleLoading = false);
  //   await _handleResult(result);
  // }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    bool ok = true;
    final email = _emailCtrl.text.trim();
    // Basic format: must contain @ and have something on both sides
    if (email.isEmpty ||
        !email.contains('@') ||
        email.split('@').last.isEmpty) {
      setState(() => _emailError = 'Please enter a valid email address');
      ok = false;
    }
    // Supabase minimum is 6 characters
    if (_passwordCtrl.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      ok = false;
    }
    return ok;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _isLoading = true;
      _emailConfirmationPending = false;
    });

    final AuthResult result;
    if (_isSignUp) {
      result = await AuthService.instance.signUpWithEmail(
        _emailCtrl.text,
        _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Supabase returns success but session == null when email confirmation
      // is required. Check: if success but we still have no current session,
      // it means "confirm email first".
      final hasSession =
          Supabase.instance.client.auth.currentSession != null;
      if (result.success && !hasSession) {
        // Email confirmation is ON — stay on screen, show message
        setState(() => _emailConfirmationPending = true);
        return;
      }
    } else {
      result = await AuthService.instance.signInWithEmail(
        _emailCtrl.text,
        _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    await _handleResult(result);
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _emailError = null;
      _passwordError = null;
      _generalError = null;
      _emailConfirmationPending = false;
    });
  }

  void _openTerms() =>
      launchUrl(Uri.parse('https://healthapp.example.com/terms'));
  void _openPrivacy() =>
      launchUrl(Uri.parse('https://healthapp.example.com/privacy'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background gradient + logo ───────────────────────────────────
          Positioned.fill(child: _buildBackground(context)),
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
          height: size.height * 0.40,
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
                  style:
                      AppTextStyles.bodySecondary.copyWith(fontSize: 15, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
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

            Text(
              _isSignUp ? 'Create account' : 'Welcome back',
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _isSignUp
                  ? 'Your data stays private and is only visible to you.'
                  : 'Good to have you back.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 22),

            // TEMP: Google/Apple auth disabled for testing — restore block below
            // when Google + Apple providers are configured in Supabase Dashboard.
            //
            // _GoogleButton(loading: _googleLoading, onTap: _googleSignIn),
            // const SizedBox(height: 12),
            // if (Platform.isIOS) ...[
            //   _AppleButton(loading: _appleLoading, onTap: _appleSignIn),
            //   const SizedBox(height: 12),
            // ],
            // _OrDivider(),
            // const SizedBox(height: 16),
            // END TEMP disabled block

            // ── Email confirmation banner ───────────────────────────────────
            if (_emailConfirmationPending) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Check your email to confirm your account, then sign in here.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primaryAccent),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Email field ────────────────────────────────────────────────
            _label('Email'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              style: AppTextStyles.body,
              onChanged: (_) => setState(() {
                _emailError = null;
                _generalError = null;
                _emailConfirmationPending = false;
              }),
              decoration: _inputDecoration(
                hint: 'you@example.com',
                errorText: _emailError,
              ),
            ),
            if (_emailError != null) _errorText(_emailError!),
            const SizedBox(height: 16),

            // ── Password field ─────────────────────────────────────────────
            _label('Password'),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: AppTextStyles.body,
              onChanged: (_) => setState(() {
                _passwordError = null;
                _generalError = null;
              }),
              decoration: _inputDecoration(
                hint: '••••••••',
                errorText: _passwordError,
                suffix: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (_passwordError != null) _errorText(_passwordError!),
            const SizedBox(height: 22),

            // ── General error banner ───────────────────────────────────────
            if (_generalError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.destructive.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _generalError!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.destructive),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Primary button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  disabledBackgroundColor:
                      AppColors.primaryAccent.withValues(alpha: 0.5),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black87),
                      )
                    : Text(
                        _isSignUp ? 'Create account' : 'Sign in',
                        style: AppTextStyles.buttonLabel,
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Legal text ─────────────────────────────────────────────────
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.secondaryText, fontSize: 11),
                  children: [
                    const TextSpan(text: 'By continuing you agree to our '),
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

            // ── Sign-in / Sign-up toggle ────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _toggleMode,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.secondaryText),
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Sign in' : 'Sign up',
                          style: const TextStyle(
                            color: AppColors.primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _label(String t) =>
      Text(t, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600));

  Widget _errorText(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(
          t,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.destructive, fontSize: 12),
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    String? errorText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
      errorText: null,
      suffixIcon: suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            )
          : null,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppColors.cardSurface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: errorText != null ? AppColors.destructive : AppColors.divider,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: errorText != null
              ? AppColors.destructive
              : AppColors.primaryAccent,
          width: 1.5,
        ),
      ),
    );
  }
}

// ── PRESERVED — Google + Apple button widgets (DO NOT DELETE) ─────────────────
// These are kept here so they can be restored without a rewrite.
// To restore:
//   1. Remove the 'ignore_for_file: unused_element' suppress below
//   2. Re-import 'signin_screen.dart' and 'signup_screen.dart'
//   3. Uncomment the call sites in _buildBottomPanel()
//   4. Uncomment _googleSignIn(), _appleSignIn(), and the loading state fields
//
// ignore: unused_element
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
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black54))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

// ignore: unused_element
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
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.57, 1.57, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        0, 1.57, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        1.57, 1.57, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        3.14, 1.57, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.62, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
          center.dx, center.dy - radius * 0.18, radius, radius * 0.36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
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
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70))
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

// ignore: unused_element
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
