import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/models/file_entry.dart';

/// Current folder being viewed. `null` = root.
final currentFolderProvider = StateProvider<String?>((ref) => null);

final filesProvider =
    StateNotifierProvider<FilesNotifier, AsyncValue<List<FileEntry>>>((ref) {
  final client = ref.watch(apiClientProvider);
  final parentId = ref.watch(currentFolderProvider);
  return FilesNotifier(client, parentId)..load();
});

class FilesNotifier extends StateNotifier<AsyncValue<List<FileEntry>>> {
  FilesNotifier(this._client, this._parentId)
      : super(const AsyncValue.loading());

  final ApiClient _client;
  final String? _parentId;

  Future<void> load() async {
    try {
      final data = await _client.listFiles(parentId: _parentId);
      state = AsyncValue.data(data.map(FileEntry.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> upload(Uint8List data, String filename) async {
    await _client.uploadFile(data, filename, parentId: _parentId);
    await load();
  }

  Future<void> createFolder(String name) async {
    await _client.createFolder(name, parentId: _parentId);
    await load();
  }

  Future<void> rename(String id, String newName) async {
    await _client.renameFile(id, newName);
    await load();
  }

  Future<void> move(String id, {String? targetParentId}) async {
    await _client.moveFile(id, parentId: targetParentId);
    await load();
  }

  Future<void> delete(String id) async {
    await _client.deleteFile(id);
    await load();
  }
}
