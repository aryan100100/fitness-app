// [HEALTH APP] — Progress Photo Opt-in Card (Feature 9)
// Full-screen opt-in shown the first time a user navigates to Progress Photos.
// Entirely optional — "No thanks" suppresses this permanently.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/user_model.dart';
import 'progress_photos_screen.dart';

class ProgressPhotoOptInCard extends StatefulWidget {
  final UserModel user;

  const ProgressPhotoOptInCard({super.key, required this.user});

  @override
  State<ProgressPhotoOptInCard> createState() => _ProgressPhotoOptInCardState();
}

class _ProgressPhotoOptInCardState extends State<ProgressPhotoOptInCard> {
  bool _isEnabling = false;

  Future<void> _enablePhotos() async {
    setState(() => _isEnabling = true);
    try {
      await Supabase.instance.client
          .from('users')
          .update({'progress_photos_enabled': true}).eq(
              'id', widget.user.id ?? '');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProgressPhotosScreen(
              user: widget.user.copyWith(progressPhotosEnabled: true),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isEnabling = false);
    }
  }

  Future<void> _noThanks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        'progress_photo_skip_${widget.user.id}', true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.primaryText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primaryAccent, size: 48),
              ),
            ),
            const SizedBox(height: 28),

            Text('Track your progress visually 📸',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),

            Text(
              'Progress photos are a private, optional tool to see how your body changes over time. They\'re stored securely and only visible to you — never shared anywhere.',
              style: AppTextStyles.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),

            Text(
              'We recommend taking photos every 2–4 weeks. Comparing photos too frequently can be unhelpful and discouraging — most meaningful changes take weeks to appear.',
              style: AppTextStyles.bodySecondary.copyWith(height: 1.5),
            ),
            const SizedBox(height: 28),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Progress photos are optional. If they ever make you feel worse rather than better, you can delete them all and turn this feature off at any time. Other progress metrics like weight trends and streaks work just as well.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondaryText, height: 1.4),
              ),
            ),

            const SizedBox(height: 36),

            // Primary button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isEnabling ? null : _enablePhotos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isEnabling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text('Turn on progress photos',
                        style: AppTextStyles.buttonLabel
                            .copyWith(color: Colors.black)),
              ),
            ),

            const SizedBox(height: 12),

            // Skip button
            Center(
              child: TextButton(
                onPressed: _noThanks,
                child: Text('No thanks, skip this',
                    style: AppTextStyles.bodySecondary),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
