class Photo {
  const Photo({
    required this.id,
    required this.filename,
    required this.storageKey,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.cameraMake,
    this.cameraModel,
    this.width,
    this.height,
    this.fileSize,
    this.mediaType = 'photo',
    this.durationSecs,
    this.videoCodec,
    required this.createdAt,
  });

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
        id: json['id'] as String,
        filename: json['filename'] as String,
        storageKey: json['storage_key'] as String,
        takenAt: json['taken_at'] != null ? DateTime.parse(json['taken_at'] as String) : null,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        cameraMake: json['camera_make'] as String?,
        cameraModel: json['camera_model'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        fileSize: json['file_size'] as int?,
        mediaType: json['media_type'] as String? ?? 'photo',
        durationSecs: (json['duration_secs'] as num?)?.toDouble(),
        videoCodec: json['video_codec'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String filename;
  final String storageKey;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final String? cameraMake;
  final String? cameraModel;
  final int? width;
  final int? height;
  final int? fileSize;
  final String mediaType;
  final double? durationSecs;
  final String? videoCodec;
  final DateTime createdAt;

  bool get isVideo => mediaType == 'video';

  DateTime get displayDate => takenAt ?? createdAt;

  String? get humanDuration {
    if (durationSecs == null) return null;
    final total = durationSecs!.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String? get humanSize {
    if (fileSize == null) return null;
    final s = fileSize!;
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} KB';
    if (s < 1024 * 1024 * 1024) return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(s / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
