import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
        onPressed: () => _pickAndUpload(ref),
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    final notifier = ref.read(filesProvider.notifier);
    for (final file in result.files) {
      final bytes = file.bytes ?? (file.path != null ? await _readFile(file.path!) : null);
      if (bytes != null) {
        await notifier.upload(bytes, file.name);
      }
    }
  }

  Future<Uint8List> _readFile(String path) async {
    final file = File(path);
    return file.readAsBytes();
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
          if (action == 'download') {
            _download(context, ref);
          } else if (action == 'delete') {
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

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${file.filename}';
      await client.downloadFile(file.id, path);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
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
