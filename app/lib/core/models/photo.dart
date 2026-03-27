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
  final DateTime createdAt;

  DateTime get displayDate => takenAt ?? createdAt;
}
