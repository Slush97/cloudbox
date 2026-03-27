import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/file_entry.dart';

final filesProvider = StateNotifierProvider<FilesNotifier, AsyncValue<List<FileEntry>>>((ref) {
  final client = ref.watch(apiClientProvider);
  return FilesNotifier(client)..load();
});

class FilesNotifier extends StateNotifier<AsyncValue<List<FileEntry>>> {
  FilesNotifier(this._client) : super(const AsyncValue.loading());

  final ApiClient _client;

  Future<void> load() async {
    try {
      final data = await _client.listFiles();
      state = AsyncValue.data(data.map(FileEntry.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> upload(Uint8List data, String filename) async {
    await _client.uploadFile(data, filename);
    await load();
  }

  Future<void> delete(String id) async {
    await _client.deleteFile(id);
    await load();
  }
}
