import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/client.dart';
import '../providers/trash_provider.dart';

class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashProvider);
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          trash.whenOrNull(
                data: (data) => data.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_forever),
                        tooltip: 'Empty trash',
                        onPressed: () => _confirmEmpty(context, ref),
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Trash is empty'),
                  SizedBox(height: 8),
                  Text('Items moved to trash are permanently deleted after 30 days.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          final dateFormat = DateFormat.yMd().add_jm();
          return RefreshIndicator(
            onRefresh: () => ref.read(trashProvider.notifier).load(),
            child: ListView(
              children: [
                if (data.photos.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Photos (${data.photos.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  for (final photo in data.photos)
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CachedNetworkImage(
                            imageUrl: client.thumbnailUrl(photo.id, size: 'sm'),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      title: Text(photo.filename, overflow: TextOverflow.ellipsis),
                      subtitle: photo.deletedAt != null
                          ? Text('Deleted ${dateFormat.format(photo.deletedAt!)}')
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'restore') {
                            ref.read(trashProvider.notifier).restorePhoto(photo.id);
                          } else if (action == 'delete') {
                            _confirmPermanentDelete(context, ref, 'photo', photo.id, photo.filename);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'restore', child: Text('Restore')),
                          PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                        ],
                      ),
                    ),
                ],
                if (data.files.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Files (${data.files.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  for (final file in data.files)
                    ListTile(
                      leading: Icon(file.icon),
                      title: Text(file.filename, overflow: TextOverflow.ellipsis),
                      subtitle: file.deletedAt != null
                          ? Text('Deleted ${dateFormat.format(file.deletedAt!)}')
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'restore') {
                            ref.read(trashProvider.notifier).restoreFile(file.id);
                          } else if (action == 'delete') {
                            _confirmPermanentDelete(context, ref, 'file', file.id, file.filename);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'restore', child: Text('Restore')),
                          PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    String type,
    String id,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('"$name" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete permanently',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (type == 'photo') {
        await ref.read(trashProvider.notifier).permanentDeletePhoto(id);
      } else {
        await ref.read(trashProvider.notifier).permanentDeleteFile(id);
      }
    }
  }

  Future<void> _confirmEmpty(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty trash?'),
        content: const Text('All items in trash will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Empty trash',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(trashProvider.notifier).emptyTrash();
    }
  }
}
