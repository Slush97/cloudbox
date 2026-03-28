import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../providers/photos_provider.dart';
import 'photo_detail_page.dart';

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider);
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: photos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => _PhotoGrid(photos: list, client: client),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUpload(ref),
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    final notifier = ref.read(photosProvider.notifier);
    for (final file in files) {
      final bytes = await file.readAsBytes();
      await notifier.upload(bytes, file.name);
    }
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.photos, required this.client});

  final List<Photo> photos;
  final ApiClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photos.isEmpty) {
      return const Center(child: Text('No photos yet. Tap + to upload.'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(photosProvider.notifier).load(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            ref.read(photosProvider.notifier).loadMore();
          }
          return false;
        },
        child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: MediaQuery.sizeOf(context).width >= 800 ? 200 : 120,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhotoDetailPage(photo: photo),
              ),
            ),
            child: Hero(
              tag: 'photo_${photo.id}',
              child: CachedNetworkImage(
                imageUrl: client.thumbnailUrl(photo.id, size: 'md'),
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
