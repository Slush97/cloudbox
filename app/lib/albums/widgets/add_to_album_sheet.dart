import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/album.dart';
import '../providers/albums_provider.dart';

/// Bottom sheet to add one or more photos to an album.
/// Returns the album name if photos were added, null if cancelled.
Future<String?> showAddToAlbumSheet(
  BuildContext context,
  WidgetRef ref,
  List<String> photoIds,
) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddToAlbumSheet(photoIds: photoIds),
  );
}

class _AddToAlbumSheet extends ConsumerStatefulWidget {
  const _AddToAlbumSheet({required this.photoIds});
  final List<String> photoIds;

  @override
  ConsumerState<_AddToAlbumSheet> createState() => _AddToAlbumSheetState();
}

class _AddToAlbumSheetState extends ConsumerState<_AddToAlbumSheet> {
  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(albumsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Add to album',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                    onPressed: () => _createAndAdd(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: albums.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(child: Text('No albums. Create one first.'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final album = list[index];
                      return ListTile(
                        leading: const Icon(Icons.photo_album_outlined),
                        title: Text(album.name),
                        subtitle: Text('${album.photoCount} photos'),
                        onTap: () => _addToAlbum(album),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToAlbum(Album album) async {
    final client = ref.read(apiClientProvider);
    await client.addPhotosToAlbum(album.id, widget.photoIds);
    ref.invalidate(albumsProvider);
    if (mounted) Navigator.of(context).pop(album.name);
  }

  Future<void> _createAndAdd(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New album'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Album name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final album = await ref.read(albumsProvider.notifier).create(name);
      final client = ref.read(apiClientProvider);
      await client.addPhotosToAlbum(album.id, widget.photoIds);
      ref.invalidate(albumsProvider);
      if (mounted) Navigator.of(context).pop(album.name);
    }
  }
}
