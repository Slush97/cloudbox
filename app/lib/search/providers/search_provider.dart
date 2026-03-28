import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';

/// null = no search yet, empty = no results, non-empty = results
final searchResultsProvider =
    StateNotifierProvider<SearchNotifier, AsyncValue<List<Photo>?>>((ref) {
  final client = ref.watch(apiClientProvider);
  return SearchNotifier(client);
});

class SearchNotifier extends StateNotifier<AsyncValue<List<Photo>?>> {
  SearchNotifier(this._client) : super(const AsyncValue.data(null));

  final ApiClient _client;

  Future<void> search(
    String query, {
    String? mediaType,
    bool? hasLocation,
    String? dateFrom,
    String? dateTo,
  }) async {
    final hasQuery = query.trim().isNotEmpty;
    final hasFilters = mediaType != null || hasLocation == true || dateFrom != null || dateTo != null;

    if (!hasQuery && !hasFilters) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      List<Map<String, dynamic>> data;
      if (hasQuery) {
        // Semantic search via CLIP — filters are not combined with CLIP yet
        data = await _client.searchPhotos(query);
      } else {
        // Filter-only search via list endpoint
        data = await _client.listPhotos(
          limit: 100,
          mediaType: mediaType,
          hasLocation: hasLocation,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
      }
      state = AsyncValue.data(data.map(Photo.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}
