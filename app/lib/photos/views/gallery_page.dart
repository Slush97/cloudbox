import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../albums/views/albums_page.dart';
import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../providers/photos_provider.dart';
import '../providers/selection_provider.dart';
import '../widgets/date_scroller.dart';
import '../widgets/selection_bar.dart';
import 'device_photos_page.dart';
import 'photo_detail_page.dart';

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(photosProvider);
    final client = ref.watch(apiClientProvider);
    final isSelecting = ref.watch(selectionModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_album_outlined),
            tooltip: 'Albums',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AlbumsPage()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          photos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (list) => _PhotoGrid(photos: list, client: client),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: isSelecting
                    ? const SelectionBar()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isSelecting
          ? null
          : FloatingActionButton(
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('No photos yet'),
            const SizedBox(height: 8),
            Text('Tap + to upload from your camera roll',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final groups =
        groupByMonth(widget.photos, (p) => p.displayDate);
    final sections = buildSections(groups);
    final crossAxisCount =
        MediaQuery.sizeOf(context).width >= 800 ? 5 : 3;

    // Build a flat index for photo detail navigation
    final allPhotos = widget.photos;
    final photoIndex = {
      for (var i = 0; i < allPhotos.length; i++) allPhotos[i].id: i,
    };

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
                      final globalIndex = photoIndex[photo.id] ?? 0;
                      final isSelecting = ref.watch(selectionModeProvider);
                      final selectedIds = ref.watch(selectedPhotoIdsProvider);
                      final isSelected = selectedIds.contains(photo.id);

                      return GestureDetector(
                        onTap: () {
                          if (isSelecting) {
                            final ids = ref.read(selectedPhotoIdsProvider.notifier);
                            if (isSelected) {
                              ids.state = {...ids.state}..remove(photo.id);
                              if (ids.state.isEmpty) {
                                ref.read(selectionModeProvider.notifier).state = false;
                              }
                            } else {
                              ids.state = {...ids.state, photo.id};
                            }
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PhotoDetailPage(
                                  photos: allPhotos,
                                  initialIndex: globalIndex,
                                ),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          if (!isSelecting) {
                            HapticFeedback.mediumImpact();
                            ref.read(selectionModeProvider.notifier).state = true;
                            ref.read(selectedPhotoIdsProvider.notifier).state = {photo.id};
                          }
                        },
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
                            if (isSelecting)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.black38,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                                      : null,
                                ),
                              ),
                            if (photo.isFavorited && !isSelecting)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(Icons.favorite,
                                    color: Colors.white, size: 18,
                                    shadows: [Shadow(blurRadius: 4)]),
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
