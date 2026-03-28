import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/album.dart';
import '../../photos/views/photo_detail_page.dart';
import '../../shared/widgets/error_display.dart';
import '../providers/albums_provider.dart';

class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({required this.album, super.key});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(albumPhotosFamily(album.id));
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(album.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => _onAction(action, context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete album')),
            ],
          ),
        ],
      ),
      body: photos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorDisplay(
          error: e,
          onRetry: () => ref.invalidate(albumPhotosFamily(album.id)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No photos in this album'));
          }
          final crossAxisCount = MediaQuery.sizeOf(context).width >= 800 ? 5 : 3;
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                ref.read(albumPhotosFamily(album.id).notifier).loadMore();
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final photo = list[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PhotoDetailPage(
                        photos: list,
                        initialIndex: index,
                      ),
                    ),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: client.thumbnailUrl(photo.id, size: 'md'),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onAction(String action, BuildContext context, WidgetRef ref) {
    switch (action) {
      case 'rename':
        _rename(context, ref);
      case 'delete':
        _deleteAlbum(context, ref);
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: album.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename album'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != album.name) {
      await ref.read(albumsProvider.notifier).update(album.id, newName);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteAlbum(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete album?'),
        content: const Text('The album will be deleted but the photos will remain in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(albumsProvider.notifier).delete(album.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
