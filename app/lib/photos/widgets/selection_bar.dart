import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../albums/widgets/add_to_album_sheet.dart';
import '../../core/api/client.dart';
import '../providers/photos_provider.dart';
import '../providers/selection_provider.dart';

class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPhotoIdsProvider);
    if (selected.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: () {
              ref.read(selectionModeProvider.notifier).state = false;
              ref.read(selectedPhotoIdsProvider.notifier).state = {};
            },
          ),
          Text('${selected.length} selected',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Favorite',
            onPressed: () => _batchFavorite(ref),
          ),
          IconButton(
            icon: const Icon(Icons.photo_album_outlined),
            tooltip: 'Add to album',
            onPressed: () => _addToAlbum(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            tooltip: 'Move to trash',
            onPressed: () => _batchDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _batchFavorite(WidgetRef ref) async {
    final ids = ref.read(selectedPhotoIdsProvider).toList();
    final client = ref.read(apiClientProvider);
    await client.batchFavoritePhotos(ids, true);
    ref.read(selectionModeProvider.notifier).state = false;
    ref.read(selectedPhotoIdsProvider.notifier).state = {};
    await ref.read(photosProvider.notifier).load();
  }

  Future<void> _addToAlbum(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(selectedPhotoIdsProvider).toList();
    final albumName = await showAddToAlbumSheet(context, ref, ids);
    if (albumName != null) {
      ref.read(selectionModeProvider.notifier).state = false;
      ref.read(selectedPhotoIdsProvider.notifier).state = {};
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${ids.length} photos to "$albumName"')),
        );
      }
    }
  }

  Future<void> _batchDelete(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(selectedPhotoIdsProvider).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to trash?'),
        content: Text('Move ${ids.length} photos to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Move to trash',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final client = ref.read(apiClientProvider);
      await client.batchDeletePhotos(ids);
      ref.read(selectionModeProvider.notifier).state = false;
      ref.read(selectedPhotoIdsProvider.notifier).state = {};
      await ref.read(photosProvider.notifier).load();
    }
  }
}
