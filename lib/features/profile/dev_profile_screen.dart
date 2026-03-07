// [HEALTH APP] — Dev Profile Screen
// Temporary dev-only screen in the Profile tab.
// Provides a "Sign Out" button to clear the session and restart onboarding.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../onboarding/onboarding_screen.dart';

class DevProfileScreen extends StatefulWidget {
  const DevProfileScreen({super.key});

  @override
  State<DevProfileScreen> createState() => _DevProfileScreenState();
}

class _DevProfileScreenState extends State<DevProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Ignore errors — session cleared locally either way
    }
    if (!mounted) return;
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
        title: Text('Profile', style: AppTextStyles.headingMedium),
        centerTitle: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sign Out button
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: _isSigningOut ? null : _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5252),
                  side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSigningOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF5252)),
                        ),
                      )
                    : const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  _isSigningOut ? 'Signing out…' : 'Sign Out',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF5252),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dev mode — tap to clear session and restart onboarding',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
