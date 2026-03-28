import 'package:flutter/material.dart';

class FileEntry {
  const FileEntry({
    required this.id,
    required this.filename,
    required this.storageKey,
    required this.sizeBytes,
    this.parentId,
    this.mimeType,
    required this.isFolder,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorited = false,
    this.deletedAt,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
        id: json['id'] as String,
        filename: json['filename'] as String,
        storageKey: json['storage_key'] as String,
        sizeBytes: json['size_bytes'] as int,
        parentId: json['parent_id'] as String?,
        mimeType: json['mime_type'] as String?,
        isFolder: json['is_folder'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isFavorited: json['is_favorited'] as bool? ?? false,
        deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
      );

  final String id;
  final String filename;
  final String storageKey;
  final int sizeBytes;
  final String? parentId;
  final String? mimeType;
  final bool isFolder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorited;
  final DateTime? deletedAt;

  String get humanSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData get icon {
    if (isFolder) return Icons.folder;
    final mime = mimeType ?? '';
    final ext = filename.split('.').last.toLowerCase();
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.startsWith('audio/')) return Icons.audiotrack;
    if (mime == 'application/pdf' || ext == 'pdf') return Icons.picture_as_pdf;
    if (mime.startsWith('text/')) return Icons.description;
    if ({'zip', 'gz', 'tar', 'rar', '7z'}.contains(ext)) return Icons.archive;
    if ({'doc', 'docx', 'odt'}.contains(ext)) return Icons.article;
    if ({'xls', 'xlsx', 'ods', 'csv'}.contains(ext)) return Icons.table_chart;
    if ({'ppt', 'pptx', 'odp'}.contains(ext)) return Icons.slideshow;
    return Icons.insert_drive_file;
  }
}
