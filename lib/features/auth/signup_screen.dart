// [HEALTH APP] — Sign Up Screen (Feature 12)
// Email + password account creation. Inline error messages, no popups.

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/auth_service.dart';
import '../onboarding/onboarding_screen.dart';
import 'signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _generalError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _generalError = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    bool ok = true;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email address');
      ok = false;
    }
    if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      ok = false;
    }
    if (password != confirm) {
      setState(() => _confirmError = 'Passwords do not match');
      ok = false;
    }
    return ok;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);
    final result = await AuthService.instance.signUpWithEmail(
      _emailCtrl.text,
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() => _generalError = result.error);
      return;
    }

    // New user — go to onboarding
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
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
        title: Text('Create account', style: AppTextStyles.body),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Create your account',
                  style: AppTextStyles.headingLarge.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('Free forever. No credit card required.',
                  style: AppTextStyles.bodySecondary),
              const SizedBox(height: 32),

              // ── Email ──────────────────────────────────────────────────────
              _label('Email'),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.body,
                onChanged: (_) => setState(() => _emailError = null),
                decoration: _inputDecoration(
                    hint: 'you@example.com', errorText: _emailError),
              ),
              if (_emailError != null) _errorText(_emailError!),
              const SizedBox(height: 18),

              // ── Password ───────────────────────────────────────────────────
              _label('Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.body,
                onChanged: (_) => setState(() => _passwordError = null),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  errorText: _passwordError,
                  suffix: _toggleIcon(
                    obscure: _obscurePassword,
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (_passwordError != null)
                _errorText(_passwordError!)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text('Minimum 8 characters',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.secondaryText, fontSize: 12)),
                ),
              const SizedBox(height: 18),

              // ── Confirm password ───────────────────────────────────────────
              _label('Confirm password'),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: AppTextStyles.body,
                onChanged: (_) => setState(() => _confirmError = null),
                decoration: _inputDecoration(
                  hint: '••••••••',
                  errorText: _confirmError,
                  suffix: _toggleIcon(
                    obscure: _obscureConfirm,
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              if (_confirmError != null) _errorText(_confirmError!),
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
                      : Text('Create account',
                          style: AppTextStyles.buttonLabel),
                ),
              ),
              const SizedBox(height: 24),

              // ── Sign in link ───────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
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

  Widget _toggleIcon({required bool obscure, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.secondaryText,
          size: 20,
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    String? errorText,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
      errorText: null, // We handle errors ourselves
      suffixIcon: suffix != null ? Padding(
        padding: const EdgeInsets.only(right: 12),
        child: suffix,
      ) : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
