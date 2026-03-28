class Album {
  const Album({
    required this.id,
    required this.name,
    this.coverPhotoId,
    required this.createdAt,
    required this.updatedAt,
    this.photoCount = 0,
  });

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        id: json['id'] as String,
        name: json['name'] as String,
        coverPhotoId: json['cover_photo_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        photoCount: json['photo_count'] as int? ?? 0,
      );

  final String id;
  final String name;
  final String? coverPhotoId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int photoCount;
}
