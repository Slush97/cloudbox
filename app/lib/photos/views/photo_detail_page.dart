import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../albums/widgets/add_to_album_sheet.dart';
import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../../core/models/photo_tag.dart';
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
            icon: Icon(
              _currentPhoto.isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _currentPhoto.isFavorited ? Colors.red : null,
            ),
            onPressed: () => _toggleFavorite(),
          ),
          IconButton(
            icon: const Icon(Icons.photo_album_outlined),
            onPressed: () => _addToAlbum(context),
          ),
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
          if (photo.isVideo) {
            return _VideoPlayerView(
              streamUrl: client.videoStreamUrl(photo.id),
              thumbnailUrl: client.thumbnailUrl(photo.id, size: 'lg'),
            );
          }
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

  Future<void> _addToAlbum(BuildContext context) async {
    final albumName = await showAddToAlbumSheet(
      context,
      ref,
      [_currentPhoto.id],
    );
    if (albumName != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added to "$albumName"')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    await ref.read(photosProvider.notifier).toggleFavorite(_currentPhoto.id);
    setState(() {});
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to trash?'),
        content: const Text(
            'This photo will be moved to trash and permanently deleted after 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Move to trash',
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
    final client = ref.read(apiClientProvider);
    final dateFormat = DateFormat.yMMMMd().add_jm();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PhotoInfoSheet(
        photo: photo,
        client: client,
        dateFormat: dateFormat,
      ),
    );
  }
}

class _PhotoInfoSheet extends StatefulWidget {
  const _PhotoInfoSheet({
    required this.photo,
    required this.client,
    required this.dateFormat,
  });

  final Photo photo;
  final ApiClient client;
  final DateFormat dateFormat;

  @override
  State<_PhotoInfoSheet> createState() => _PhotoInfoSheetState();
}

class _PhotoInfoSheetState extends State<_PhotoInfoSheet> {
  late Future<List<PhotoTag>> _tagsFuture;
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tagsFuture = _loadTags();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<List<PhotoTag>> _loadTags() async {
    final data = await widget.client.getPhotoTags(widget.photo.id);
    return data.map(PhotoTag.fromJson).toList();
  }

  Future<void> _addTag() async {
    final name = _tagController.text.trim().toLowerCase();
    if (name.isEmpty) return;
    await widget.client.addPhotoTag(widget.photo.id, name);
    _tagController.clear();
    setState(() => _tagsFuture = _loadTags());
  }

  Future<void> _removeTag(int tagId) async {
    await widget.client.removePhotoTag(widget.photo.id, tagId);
    setState(() => _tagsFuture = _loadTags());
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(photo.filename,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _InfoRow('Date', widget.dateFormat.format(photo.displayDate)),
          if (photo.width != null && photo.height != null)
            _InfoRow('Resolution', '${photo.width} x ${photo.height}'),
          if (photo.humanSize != null)
            _InfoRow('Size', photo.humanSize!),
          if (photo.isVideo && photo.humanDuration != null)
            _InfoRow('Duration', photo.humanDuration!),
          if (photo.videoCodec != null)
            _InfoRow('Codec', photo.videoCodec!),
          if (photo.cameraMake != null || photo.cameraModel != null ||
              photo.aperture != null || photo.iso != null) ...[
            const SizedBox(height: 12),
            Text('Camera', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (photo.cameraMake != null || photo.cameraModel != null)
              _InfoRow(
                  'Model',
                  [photo.cameraMake, photo.cameraModel]
                      .whereType<String>()
                      .join(' ')),
            if (photo.lensModel != null)
              _InfoRow('Lens', photo.lensModel!),
            if (photo.aperture != null)
              _InfoRow('Aperture', photo.aperture!),
            if (photo.shutterSpeed != null)
              _InfoRow('Shutter', photo.shutterSpeed!),
            if (photo.iso != null)
              _InfoRow('ISO', '${photo.iso}'),
            if (photo.focalLength != null)
              _InfoRow('Focal length', photo.focalLength!),
          ],
          if (photo.latitude != null && photo.longitude != null) ...[
            const SizedBox(height: 12),
            Text('Location', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _InfoRow(
                'Coordinates',
                '${photo.latitude!.toStringAsFixed(4)}, '
                '${photo.longitude!.toStringAsFixed(4)}'),
          ],
          const SizedBox(height: 16),
          Text('Tags', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          FutureBuilder<List<PhotoTag>>(
            future: _tagsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 32,
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))),
                );
              }
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) {
                return Text('No tags yet',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline));
              }
              return Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags
                    .map((tag) => Chip(
                          label: Text(tag.tagName),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag.tagId),
                          side: tag.isManual
                              ? null
                              : BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    hintText: 'Add tag...',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addTag,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  const _VideoPlayerView({
    required this.streamUrl,
    required this.thumbnailUrl,
  });

  final String streamUrl;
  final String thumbnailUrl;

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        await controller.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video playback error: $e')),
        );
      }
    }
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !_initialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Show poster frame with play button
      return GestureDetector(
        onTap: _initPlayer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: widget.thumbnailUrl,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 48),
              ),
            ),
          ],
        ),
      );
    }

    final controller = _controller!;

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (_showControls) ...[
            // Play/pause overlay
            Center(
              child: IconButton(
                iconSize: 64,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white70,
                ),
                onPressed: _togglePlayPause,
              ),
            ),
            // Seek bar at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final pos = value.position.inMilliseconds;
                  final dur = value.duration.inMilliseconds;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: dur > 0 ? pos / dur : 0,
                          onChanged: (v) {
                            controller.seekTo(Duration(
                                milliseconds: (v * dur).round()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(value.position),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(_formatDuration(value.duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
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
