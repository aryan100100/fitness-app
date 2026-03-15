// [HEALTH APP] — Photo Timeline Entry (Feature 9)
// Reusable widget rendering one date row in the gallery timeline.
// Shows up to 3 angle thumbnails, per-thumbnail delete, full-screen tap.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/progress_photo_service.dart';
import '../../models/progress_photo_model.dart';

class PhotoTimelineEntry extends StatefulWidget {
  final DateTime date;
  final List<ProgressPhoto> photos; // up to 3 for this date
  final VoidCallback onPhotoDeleted;

  const PhotoTimelineEntry({
    super.key,
    required this.date,
    required this.photos,
    required this.onPhotoDeleted,
  });

  @override
  State<PhotoTimelineEntry> createState() => _PhotoTimelineEntryState();
}

class _PhotoTimelineEntryState extends State<PhotoTimelineEntry> {
  // signed URL cache: photoId → url
  final Map<String, String?> _urlCache = {};
  bool _loadingUrls = true;

  @override
  void initState() {
    super.initState();
    _loadSignedUrls();
  }

  Future<void> _loadSignedUrls() async {
    final results = await Future.wait(
      widget.photos.map((p) async {
        final url =
            await ProgressPhotoService.instance.getSignedUrl(p.storagePath);
        return MapEntry(p.id, url);
      }),
    );
    if (mounted) {
      setState(() {
        for (final e in results) {
          _urlCache[e.key] = e.value;
        }
        _loadingUrls = false;
      });
    }
  }

  Future<void> _confirmDelete(ProgressPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text('Delete photo?', style: AppTextStyles.body),
        content: Text(
          'This will permanently remove your ${photo.angle} photo from ${DateFormat('d MMM yyyy').format(photo.photoDate)}.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.captionAccent),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: AppTextStyles.captionAccent
                    .copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ProgressPhotoService.instance
            .deletePhoto(photo.userId, photo.id, photo.storagePath);
        widget.onPhotoDeleted();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not delete photo. Please try again.',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
      }
    }
  }

  void _openFullScreen(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhoto(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            DateFormat('d MMMM yyyy').format(widget.date),
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),

        // Thumbnails row
        Row(
          children: widget.photos.map((photo) {
            final url = _urlCache[photo.id];
            return _buildThumbnail(photo, url);
          }).toList(),
        ),

        const SizedBox(height: 8),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }

  Widget _buildThumbnail(ProgressPhoto photo, String? url) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Photo tile
                GestureDetector(
                  onTap: url != null ? () => _openFullScreen(url) : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 0.75,
                      child: _loadingUrls || url == null
                          ? Container(
                              color: AppColors.cardSurface,
                              child: url == null && !_loadingUrls
                                  ? const Icon(Icons.broken_image_outlined,
                                      color: AppColors.secondaryText, size: 28)
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryAccent)),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : Container(
                                          color: AppColors.cardSurface,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primaryAccent),
                                          ),
                                        ),
                            ),
                    ),
                  ),
                ),

                // Delete button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _confirmDelete(photo),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Angle label
            Text(
              photo.angle[0].toUpperCase() + photo.angle.substring(1),
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full screen photo viewer
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenPhoto extends StatelessWidget {
  final String url;
  const _FullScreenPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5.0,
        child: Center(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
