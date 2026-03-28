import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../providers/photos_provider.dart';

class PhotoDetailPage extends ConsumerStatefulWidget {
  const PhotoDetailPage({
    required this.photos,
    required this.initialIndex,
    super.key,
  });

  final List<Photo> photos;
  final int initialIndex;

  @override
  ConsumerState<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends ConsumerState<PhotoDetailPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Photo get _currentPhoto => widget.photos[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(apiClientProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () =>
                Share.share(client.originalUrl(_currentPhoto.id)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: SizedBox.expand(
              child: CachedNetworkImage(
                imageUrl: client.thumbnailUrl(photo.id, size: 'lg'),
                fit: BoxFit.contain,
                alignment: Alignment.center,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
            'This will permanently delete this photo and all associated data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(photosProvider.notifier).delete(_currentPhoto.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _showInfo(BuildContext context) {
    final photo = _currentPhoto;
    final dateFormat = DateFormat.yMMMMd().add_jm();

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(photo.filename,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _InfoRow('Date', dateFormat.format(photo.displayDate)),
            if (photo.cameraMake != null || photo.cameraModel != null)
              _InfoRow(
                  'Camera',
                  [photo.cameraMake, photo.cameraModel]
                      .whereType<String>()
                      .join(' ')),
            if (photo.width != null && photo.height != null)
              _InfoRow(
                  'Resolution', '${photo.width} x ${photo.height}'),
            if (photo.latitude != null && photo.longitude != null)
              _InfoRow(
                  'Location',
                  '${photo.latitude!.toStringAsFixed(4)}, '
                  '${photo.longitude!.toStringAsFixed(4)}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
