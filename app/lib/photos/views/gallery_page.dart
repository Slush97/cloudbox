import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../providers/photos_provider.dart';
import '../widgets/date_scroller.dart';
import 'device_photos_page.dart';
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
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DevicePhotosPage(),
          ),
        ),
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

class _PhotoGrid extends ConsumerStatefulWidget {
  const _PhotoGrid({required this.photos, required this.client});

  final List<Photo> photos;
  final ApiClient client;

  @override
  ConsumerState<_PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends ConsumerState<_PhotoGrid> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const Center(child: Text('No photos yet. Tap + to upload.'));
    }

    final groups =
        groupByMonth(widget.photos, (p) => p.displayDate);
    final sections = buildSections(groups);
    final crossAxisCount =
        MediaQuery.sizeOf(context).width >= 800 ? 5 : 3;

    // Build a flat index for photo detail navigation
    final allPhotos = widget.photos;

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
        child: DateScroller(
          controller: _scrollController,
          sectionKeys: sections,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              for (final (label, items) in groups) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(label,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final photo = items[index];
                      final globalIndex = allPhotos.indexOf(photo);

                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoDetailPage(
                              photos: allPhotos,
                              initialIndex: globalIndex,
                            ),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: widget.client
                                  .thumbnailUrl(photo.id, size: 'md'),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                            if (photo.isVideo)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.play_arrow,
                                          color: Colors.white, size: 14),
                                      if (photo.humanDuration != null) ...[
                                        const SizedBox(width: 2),
                                        Text(photo.humanDuration!,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }
}
