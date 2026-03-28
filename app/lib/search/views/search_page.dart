import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../photos/views/photo_detail_page.dart';
import '../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String? _mediaTypeFilter;
  bool _hasLocationFilter = false;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _doSearch() {
    ref.read(searchResultsProvider.notifier).search(
      _controller.text,
      mediaType: _mediaTypeFilter,
      hasLocation: _hasLocationFilter ? true : null,
      dateFrom: _dateRange?.start.toIso8601String(),
      dateTo: _dateRange?.end.toIso8601String(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final client = ref.watch(apiClientProvider);
    final hasFilters = _mediaTypeFilter != null || _hasLocationFilter || _dateRange != null;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Search photos... (e.g. "dog at the beach")',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _doSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _doSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Photos'),
                  selected: _mediaTypeFilter == 'photo',
                  onSelected: (selected) {
                    setState(() => _mediaTypeFilter = selected ? 'photo' : null);
                    if (_controller.text.isNotEmpty || hasFilters) _doSearch();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Videos'),
                  selected: _mediaTypeFilter == 'video',
                  onSelected: (selected) {
                    setState(() => _mediaTypeFilter = selected ? 'video' : null);
                    if (_controller.text.isNotEmpty || hasFilters) _doSearch();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Has location'),
                  selected: _hasLocationFilter,
                  onSelected: (selected) {
                    setState(() => _hasLocationFilter = selected);
                    if (_controller.text.isNotEmpty || hasFilters) _doSearch();
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(
                    Icons.date_range,
                    size: 18,
                    color: _dateRange != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text(_dateRange != null
                      ? '${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.month}/${_dateRange!.end.year}'
                      : 'Date range'),
                  onPressed: () => _pickDateRange(context),
                ),
                if (hasFilters) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear filters'),
                    onPressed: () {
                      setState(() {
                        _mediaTypeFilter = null;
                        _hasLocationFilter = false;
                        _dateRange = null;
                      });
                      if (_controller.text.isNotEmpty) _doSearch();
                    },
                  ),
                ],
              ],
            ),
          ),
          // Results
          Expanded(
            child: results.when(
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
                  onRefresh: () async => _doSearch(),
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
                            builder: (_) => PhotoDetailPage(
                              photos: photos,
                              initialIndex: index,
                            ),
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
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 365)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      if (_controller.text.isNotEmpty || _mediaTypeFilter != null || _hasLocationFilter) {
        _doSearch();
      }
    }
  }
}
