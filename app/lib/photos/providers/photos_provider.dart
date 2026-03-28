import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/photo.dart';

final photosProvider = StateNotifierProvider<PhotosNotifier, AsyncValue<List<Photo>>>((ref) {
  final client = ref.watch(apiClientProvider);
  return PhotosNotifier(client)..load();
});

class PhotosNotifier extends StateNotifier<AsyncValue<List<Photo>>> {
  PhotosNotifier(this._client) : super(const AsyncValue.loading());

  final ApiClient _client;
  bool _loadingMore = false;

  Future<void> load() async {
    try {
      final data = await _client.listPhotos();
      state = AsyncValue.data(data.map(Photo.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore) return;
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    _loadingMore = true;
    try {
      final cursor = current.last.id;
      final data = await _client.listPhotos(cursor: cursor);
      final more = data.map(Photo.fromJson).toList();
      if (more.isNotEmpty) {
        state = AsyncValue.data([...current, ...more]);
      }
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> delete(String id) async {
    await _client.deletePhoto(id);
    await load();
  }

  Future<void> upload(Uint8List data, String filename) async {
    await _client.uploadPhoto(data, filename);
    await load();
  }

  Future<void> toggleFavorite(String id) async {
    final result = await _client.toggleFavoritePhoto(id);
    final updated = Photo.fromJson(result);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((p) => p.id == id ? updated : p).toList(),
    );
  }
}
