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

  Future<void> load() async {
    try {
      final data = await _client.listPhotos();
      state = AsyncValue.data(data.map(Photo.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    final cursor = current.last.id;
    final data = await _client.listPhotos(cursor: cursor);
    final more = data.map(Photo.fromJson).toList();
    state = AsyncValue.data([...current, ...more]);
  }

  Future<void> upload(Uint8List data, String filename) async {
    await _client.uploadPhoto(data, filename);
    await load();
  }
}
