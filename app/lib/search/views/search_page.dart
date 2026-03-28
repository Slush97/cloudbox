import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';
import '../../photos/views/photo_detail_page.dart';
import '../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Search photos... (e.g. "dog at the beach")',
            border: InputBorder.none,
          ),
          onSubmitted: (query) {
            ref.read(searchResultsProvider.notifier).search(query);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ref.read(searchResultsProvider.notifier).search(_controller.text);
            },
          ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (photos) {
          if (photos == null) {
            final outlineColor = Theme.of(context).colorScheme.outline;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 64, color: outlineColor),
                  const SizedBox(height: 16),
                  const Text('Search your photos with natural language'),
                  Text(
                    'Powered by CLIP embeddings',
                    style: TextStyle(color: outlineColor),
                  ),
                ],
              ),
            );
          }
          if (photos.isEmpty) {
            return const Center(child: Text('No results found.'));
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(searchResultsProvider.notifier).search(_controller.text),
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
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
                  child: CachedNetworkImage(
                    imageUrl: client.thumbnailUrl(photo.id, size: 'md'),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
