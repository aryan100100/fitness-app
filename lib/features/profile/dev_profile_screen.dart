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
  bool _hideStreakCounter = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final res = await Supabase.instance.client
          .from('users')
          .select('hide_streak_counter')
          .eq('id', userId)
          .single();
          
      if (mounted) {
        setState(() {
          _hideStreakCounter = res['hide_streak_counter'] == true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PROFILE] Error loading settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHideStreak(bool value) async {
    setState(() => _hideStreakCounter = value);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      await Supabase.instance.client.from('users').update({
        'hide_streak_counter': value,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[PROFILE] Error updating hide_streak_counter: $e');
      if (mounted) {
        setState(() => _hideStreakCounter = !value); // revert on error
      }
    }
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Feature 8 toggle
                SwitchListTile(
                  title: Text('Hide streak counter', style: AppTextStyles.body),
                  subtitle: Text(
                    'Removes the streak tracker from your dashboard if it causes stress.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.secondaryText),
                  ),
                  value: _hideStreakCounter,
                  onChanged: _toggleHideStreak,
                  activeColor: AppColors.primaryAccent,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(color: AppColors.divider, height: 32),
                
                // Sign Out button
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
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
    );
  }
}
