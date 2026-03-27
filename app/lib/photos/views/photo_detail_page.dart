import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';

class PhotoDetailPage extends ConsumerWidget {
  const PhotoDetailPage({required this.photo, super.key});

  final Photo photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(uri: Uri.parse(client.originalUrl(photo.id))),
            ),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'photo_${photo.id}',
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: client.thumbnailUrl(photo.id, size: 'lg'),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd().add_jm();

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(photo.filename, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _InfoRow('Date', dateFormat.format(photo.displayDate)),
            if (photo.cameraMake != null || photo.cameraModel != null)
              _InfoRow('Camera', [photo.cameraMake, photo.cameraModel].whereType<String>().join(' ')),
            if (photo.width != null && photo.height != null)
              _InfoRow('Resolution', '${photo.width} x ${photo.height}'),
            if (photo.latitude != null && photo.longitude != null)
              _InfoRow('Location', '${photo.latitude!.toStringAsFixed(4)}, ${photo.longitude!.toStringAsFixed(4)}'),
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
