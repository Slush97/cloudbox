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
    this.isFavorited = false,
    this.deletedAt,
    this.iso,
    this.aperture,
    this.shutterSpeed,
    this.focalLength,
    this.lensModel,
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
        isFavorited: json['is_favorited'] as bool? ?? false,
        deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
        iso: json['iso'] as int?,
        aperture: json['aperture'] as String?,
        shutterSpeed: json['shutter_speed'] as String?,
        focalLength: json['focal_length'] as String?,
        lensModel: json['lens_model'] as String?,
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
  final bool isFavorited;
  final DateTime? deletedAt;
  final int? iso;
  final String? aperture;
  final String? shutterSpeed;
  final String? focalLength;
  final String? lensModel;

  Photo copyWith({bool? isFavorited}) => Photo(
        id: id,
        filename: filename,
        storageKey: storageKey,
        takenAt: takenAt,
        latitude: latitude,
        longitude: longitude,
        cameraMake: cameraMake,
        cameraModel: cameraModel,
        width: width,
        height: height,
        fileSize: fileSize,
        mediaType: mediaType,
        durationSecs: durationSecs,
        videoCodec: videoCodec,
        createdAt: createdAt,
        isFavorited: isFavorited ?? this.isFavorited,
        deletedAt: deletedAt,
        iso: iso,
        aperture: aperture,
        shutterSpeed: shutterSpeed,
        focalLength: focalLength,
        lensModel: lensModel,
      );

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
