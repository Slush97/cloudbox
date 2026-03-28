import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/file_entry.dart';
import '../../core/models/photo.dart';

class TrashState {
  const TrashState({this.photos = const [], this.files = const []});
  final List<Photo> photos;
  final List<FileEntry> files;

  bool get isEmpty => photos.isEmpty && files.isEmpty;
  int get count => photos.length + files.length;
}

final trashProvider =
    StateNotifierProvider<TrashNotifier, AsyncValue<TrashState>>((ref) {
  final client = ref.watch(apiClientProvider);
  return TrashNotifier(client)..load();
});

class TrashNotifier extends StateNotifier<AsyncValue<TrashState>> {
  TrashNotifier(this._client) : super(const AsyncValue.loading());

  final ApiClient _client;

  Future<void> load() async {
    try {
      final data = await _client.listTrash();
      final photos = (data['photos'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Photo.fromJson)
          .toList();
      final files = (data['files'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(FileEntry.fromJson)
          .toList();
      state = AsyncValue.data(TrashState(photos: photos, files: files));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restorePhoto(String id) async {
    await _client.restorePhoto(id);
    await load();
  }

  Future<void> restoreFile(String id) async {
    await _client.restoreFile(id);
    await load();
  }

  Future<void> permanentDeletePhoto(String id) async {
    await _client.permanentDeletePhoto(id);
    await load();
  }

  Future<void> permanentDeleteFile(String id) async {
    await _client.permanentDeleteFile(id);
    await load();
  }

  Future<void> emptyTrash() async {
    await _client.emptyTrash();
    await load();
  }
}
