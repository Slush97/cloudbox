import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../providers/faces_provider.dart';

class FacesPage extends ConsumerWidget {
  const FacesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clusters = ref.watch(faceClustersProvider);
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: clusters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No faces detected yet.\nUpload photos and the ML pipeline will find them.'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final cluster = list[index];
              return Column(
                children: [
                  Expanded(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundImage: cluster.samplePhotoId != null
                          ? CachedNetworkImageProvider(
                              client.thumbnailUrl(cluster.samplePhotoId!, size: 'sm'),
                            )
                          : null,
                      child: cluster.samplePhotoId == null ? const Icon(Icons.face, size: 40) : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cluster.label ?? 'Person ${cluster.clusterId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${cluster.faceCount} photos',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
