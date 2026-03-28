import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../../photos/views/photo_detail_page.dart';
import '../providers/faces_provider.dart';

class ClusterDetailPage extends ConsumerStatefulWidget {
  const ClusterDetailPage({required this.cluster, super.key});

  final FaceCluster cluster;

  @override
  ConsumerState<ClusterDetailPage> createState() => _ClusterDetailPageState();
}

class _ClusterDetailPageState extends ConsumerState<ClusterDetailPage> {
  List<Photo>? _photos;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final data = await client.clusterPhotos(widget.cluster.clusterId);
      setState(() {
        _photos = data.map(Photo.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String get _title =>
      widget.cluster.label ?? 'Person ${widget.cluster.clusterId}';

  Future<void> _rename() async {
    final controller = TextEditingController(text: widget.cluster.label ?? '');
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Name',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty && mounted) {
      final client = ref.read(apiClientProvider);
      await client.setClusterLabel(widget.cluster.clusterId, newLabel);
      // Refresh the clusters list so the faces page updates too
      ref.read(faceClustersProvider.notifier).load();
      setState(() {}); // rebuild title
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(apiClientProvider);
    // Re-read cluster from provider in case label was updated
    final clusters = ref.watch(faceClustersProvider).valueOrNull ?? [];
    final current = clusters
        .where((c) => c.clusterId == widget.cluster.clusterId)
        .firstOrNull;
    final title = current?.label ?? _title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: _rename,
          ),
        ],
      ),
      body: _buildBody(client),
    );
  }

  Widget _buildBody(ApiClient client) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    final photos = _photos!;
    if (photos.isEmpty) {
      return const Center(child: Text('No photos found for this person.'));
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent:
              MediaQuery.sizeOf(context).width >= 800 ? 200 : 120,
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
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image),
              ),
            ),
          );
        },
      ),
    );
  }
}
