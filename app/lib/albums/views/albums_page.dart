import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/album.dart';
import '../providers/albums_provider.dart';
import 'album_detail_page.dart';

class AlbumsPage extends ConsumerWidget {
  const AlbumsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Albums')),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_album_outlined, size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('No albums yet'),
                  const SizedBox(height: 8),
                  Text('Tap + to create one',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          final crossAxisCount = MediaQuery.sizeOf(context).width >= 800 ? 4 : 2;
          return RefreshIndicator(
            onRefresh: () => ref.read(albumsProvider.notifier).load(),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) => _AlbumCard(
                album: list[index],
                client: client,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createAlbum(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createAlbum(BuildContext context, WidgetRef ref) async {
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
      await ref.read(albumsProvider.notifier).create(name);
    }
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.client});

  final Album album;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AlbumDetailPage(album: album),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: album.coverPhotoId != null
                  ? CachedNetworkImage(
                      imageUrl: client.thumbnailUrl(album.coverPhotoId!, size: 'md'),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${album.photoCount} photos',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.photo_album_outlined, size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
