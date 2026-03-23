// [HEALTH APP] — Sign In Screen (Feature 12)
// Email + password sign in. Inline errors. Forgot password flow via Supabase.

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../nav_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _resetLoading = false;
  bool _resetSent = false;

  String? _emailError;
  String? _passwordError;
  String? _generalError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    bool ok = true;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email address');
      ok = false;
    }
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _passwordError = 'Please enter your password');
      ok = false;
    }
    return ok;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);
    final result = await AuthService.instance.signInWithEmail(
      _emailCtrl.text,
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      // Try to show a field-level error for password issues
      final err = result.error ?? '';
      if (err.toLowerCase().contains('password') ||
          err.toLowerCase().contains('credentials')) {
        setState(() => _passwordError = err);
      } else {
        setState(() => _generalError = err);
      }
      return;
    }

    if (result.isNewUser) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } else {
      _goToDashboard();
    }
  }

  Future<void> _goToDashboard() async {
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

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Enter your email address above first');
      return;
    }

    setState(() => _resetLoading = true);
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _resetLoading = false;
          _resetSent = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resetLoading = false;
          _generalError = 'Could not send reset email — please try again';
        });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.primaryText,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Welcome back', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Sign in',
                style: AppTextStyles.headingLarge.copyWith(fontSize: 26)),
            const SizedBox(height: 8),
            Text("Good to have you back.",
                style: AppTextStyles.bodySecondary),
            const SizedBox(height: 32),

            // ── Reset sent banner ──────────────────────────────────────────
            if (_resetSent) ...[
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
                  'Check your email for a reset link.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primaryAccent),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Email ──────────────────────────────────────────────────────
            _label('Email'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              style: AppTextStyles.body,
              onChanged: (_) => setState(() {
                _emailError = null;
                _generalError = null;
              }),
              decoration: _inputDecoration(
                  hint: 'you@example.com', errorText: _emailError),
            ),
            if (_emailError != null) _errorText(_emailError!),
            const SizedBox(height: 18),

            // ── Password ───────────────────────────────────────────────────
            Row(children: [
              _label('Password'),
              const Spacer(),
              GestureDetector(
                onTap: _resetLoading ? null : _forgotPassword,
                child: _resetLoading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.primaryAccent))
                    : Text('Forgot password?',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryAccent, fontSize: 12)),
              ),
            ]),
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
            const SizedBox(height: 28),

            // ── General error ──────────────────────────────────────────────
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
                child: Text(_generalError!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.destructive)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Submit button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text('Sign in', style: AppTextStyles.buttonLabel),
              ),
            ),
            const SizedBox(height: 24),

            // ── Sign up link ───────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.secondaryText),
                    children: const [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign up',
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
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _label(String t) => Text(t,
      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600));

  Widget _errorText(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text(t,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.destructive, fontSize: 12)),
      );

  InputDecoration _inputDecoration({
    required String hint,
    String? errorText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
      errorText: null,
      suffixIcon: suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            )
          : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: AppColors.cardSurface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color:
              errorText != null ? AppColors.destructive : AppColors.divider,
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
