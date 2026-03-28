class PhotoTag {
  const PhotoTag({
    required this.tagId,
    required this.tagName,
    required this.confidence,
    required this.source,
  });

  factory PhotoTag.fromJson(Map<String, dynamic> json) => PhotoTag(
        tagId: json['tag_id'] as int,
        tagName: json['tag_name'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        source: json['source'] as String,
      );

  final int tagId;
  final String tagName;
  final double confidence;
  final String source;

  bool get isManual => source == 'manual';
}
