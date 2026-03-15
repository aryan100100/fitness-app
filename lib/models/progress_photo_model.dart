// [HEALTH APP] — Progress Photo Model (Feature 9)
// Mirrors the progress_photos Supabase table.
// Signed URL is NEVER stored here — always fetched fresh via ProgressPhotoService.

class ProgressPhoto {
  final String id;
  final String userId;
  final DateTime photoDate;
  final String angle; // 'front' | 'side' | 'back'
  final String storagePath;
  final DateTime? createdAt;

  const ProgressPhoto({
    required this.id,
    required this.userId,
    required this.photoDate,
    required this.angle,
    required this.storagePath,
    this.createdAt,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ProgressPhoto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      photoDate: DateTime.parse(json['photo_date'] as String),
      angle: json['angle'] as String,
      storagePath: json['storage_path'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'photo_date': photoDate.toIso8601String().substring(0, 10),
      'angle': angle,
      'storage_path': storagePath,
    };
  }
}
