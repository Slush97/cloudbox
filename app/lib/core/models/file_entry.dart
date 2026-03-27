class FileEntry {
  const FileEntry({
    required this.id,
    required this.filename,
    required this.storageKey,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
        id: json['id'] as String,
        filename: json['filename'] as String,
        storageKey: json['storage_key'] as String,
        sizeBytes: json['size_bytes'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String filename;
  final String storageKey;
  final int sizeBytes;
  final DateTime createdAt;

  String get humanSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
