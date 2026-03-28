import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/album.dart';
import '../../core/models/photo.dart';

final albumsProvider =
    StateNotifierProvider<AlbumsNotifier, AsyncValue<List<Album>>>((ref) {
  final client = ref.watch(apiClientProvider);
  return AlbumsNotifier(client)..load();
});

class AlbumsNotifier extends StateNotifier<AsyncValue<List<Album>>> {
  AlbumsNotifier(this._client) : super(const AsyncValue.loading());

  final ApiClient _client;

  Future<void> load() async {
    try {
      final data = await _client.listAlbums();
      state = AsyncValue.data(data.map(Album.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Album> create(String name) async {
    final data = await _client.createAlbum(name);
    final album = Album.fromJson(data);
    await load();
    return album;
  }

  Future<void> update(String id, String name) async {
    await _client.updateAlbum(id, name);
    await load();
  }

  Future<void> delete(String id) async {
    await _client.deleteAlbum(id);
    await load();
  }
}

final albumPhotosFamily =
    StateNotifierProvider.family<AlbumPhotosNotifier, AsyncValue<List<Photo>>, String>(
        (ref, albumId) {
  final client = ref.watch(apiClientProvider);
  return AlbumPhotosNotifier(client, albumId)..load();
});

class AlbumPhotosNotifier extends StateNotifier<AsyncValue<List<Photo>>> {
  AlbumPhotosNotifier(this._client, this._albumId)
      : super(const AsyncValue.loading());

  final ApiClient _client;
  final String _albumId;
  bool _loadingMore = false;

  Future<void> load() async {
    try {
      final data = await _client.listAlbumPhotos(_albumId);
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
      final data = await _client.listAlbumPhotos(_albumId, cursor: cursor);
      final more = data.map(Photo.fromJson).toList();
      if (more.isNotEmpty) {
        state = AsyncValue.data([...current, ...more]);
      }
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> removePhoto(String photoId) async {
    await _client.removePhotoFromAlbum(_albumId, photoId);
    await load();
  }
}
