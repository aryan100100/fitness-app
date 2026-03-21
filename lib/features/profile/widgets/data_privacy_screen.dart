// [HEALTH APP] — Data & Privacy Sub-Screen (Profile Feature)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../onboarding/onboarding_screen.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  bool _isDeleting = false;

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Delete all data?', style: AppTextStyles.body
            .copyWith(color: AppColors.destructive)),
        content: Text(
          'This will permanently delete your account data, food logs, progress photos, and all settings. This cannot be undone.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.captionAccent),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete everything',
                style: AppTextStyles.captionAccent
                    .copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      // Delete food_logs, weight_logs, etc. — users row cascades on RLS
      await Future.wait([
        Supabase.instance.client.from('food_logs').delete().eq('user_id', userId),
        Supabase.instance.client.from('weight_logs').delete().eq('user_id', userId),
        Supabase.instance.client.from('streaks').delete().eq('user_id', userId),
        Supabase.instance.client.from('progress_photos').delete().eq('user_id', userId),
        Supabase.instance.client.from('custom_foods').delete().eq('user_id', userId),
        Supabase.instance.client.from('users').delete().eq('id', userId),
      ]);
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[PROFILE] Delete data error: $e');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.primaryText,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Data & Privacy', style: AppTextStyles.body),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(
            icon: Icons.lock_outline,
            title: 'Your data is private',
            body:
                'All data is stored securely in Supabase with row-level security. Only you can access your data.',
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.photo_library_outlined,
            title: 'Progress photos',
            body:
                'Photos are stored in a private storage bucket. They are never shared or used for any purpose other than showing them to you.',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Export feature coming soon 📦'),
                    backgroundColor: AppColors.cardSurface,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryAccent,
                side: const BorderSide(color: AppColors.primaryAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Export my data', style: AppTextStyles.body
                  .copyWith(color: AppColors.primaryAccent)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isDeleting ? null : _deleteAllData,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: const BorderSide(color: AppColors.destructive),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.destructive))
                  : Text('Delete all my data', style: AppTextStyles.body
                      .copyWith(color: AppColors.destructive)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
      {required IconData icon,
      required String title,
      required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryAccent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
