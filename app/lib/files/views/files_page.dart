import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/client.dart';
import '../../core/models/file_entry.dart';
import '../providers/files_provider.dart';

class FilesPage extends ConsumerWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Files')),
      body: files.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No files yet. Tap + to upload.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) => _FileTile(file: list[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: file picker
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}

class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file});
  final FileEntry file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat.yMd().add_jm();

    return ListTile(
      leading: Icon(_iconForFilename(file.filename)),
      title: Text(file.filename, overflow: TextOverflow.ellipsis),
      subtitle: Text('${file.humanSize}  -  ${dateFormat.format(file.createdAt)}'),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'delete') {
            ref.read(filesProvider.notifier).delete(file.id);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'download', child: Text('Download')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  IconData _iconForFilename(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' || 'csv' => Icons.table_chart,
      'zip' || 'tar' || 'gz' => Icons.archive,
      'mp4' || 'mov' || 'avi' || 'mkv' => Icons.video_file,
      'mp3' || 'wav' || 'flac' || 'ogg' => Icons.audio_file,
      'png' || 'jpg' || 'jpeg' || 'webp' || 'gif' => Icons.image,
      _ => Icons.insert_drive_file,
    };
  }
}
