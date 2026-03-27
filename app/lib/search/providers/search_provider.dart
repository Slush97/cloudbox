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

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final data = await _client.searchPhotos(query);
      state = AsyncValue.data(data.map(Photo.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}
