import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/auth_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authProvider);
  return ApiClient(
    baseUrl: auth.serverUrl ?? 'http://localhost:3000',
    token: auth.token,
  );
});

class ApiClient {
  ApiClient({required this.baseUrl, this.token}) {
    _dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  final String baseUrl;
  final String? token;
  late final Dio _dio;

  // Auth
  Future<Map<String, dynamic>> authStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/status');
    return res.data!;
  }

  Future<String> register(String username, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/setup',
      data: {'username': username, 'password': password},
    );
    return res.data!['token'] as String;
  }

  Future<String> login(String username, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return res.data!['token'] as String;
  }

  // Photos
  Future<List<Map<String, dynamic>>> listPhotos({
    String? cursor,
    int limit = 50,
    bool? favorites,
    String? mediaType,
    String? dateFrom,
    String? dateTo,
    bool? hasLocation,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/photos',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (favorites == true) 'favorites': true,
        if (mediaType != null) 'media_type': mediaType,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        if (hasLocation == true) 'has_location': true,
      },
    );
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> uploadPhoto(Uint8List data, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(data, filename: filename),
    });
    final res = await _dio.post<Map<String, dynamic>>('/photos/upload', data: formData);
    return res.data!;
  }

  String thumbnailUrl(String photoId, {String size = 'md'}) {
    final url = '$baseUrl/api/v1/photos/$photoId/thumb/$size';
    return token != null ? '$url?token=$token' : url;
  }

  String videoStreamUrl(String photoId) {
    final url = '$baseUrl/api/v1/photos/$photoId/stream';
    return token != null ? '$url?token=$token' : url;
  }

  Future<void> deletePhoto(String id) async {
    await _dio.delete<void>('/photos/$id');
  }

  Future<Map<String, dynamic>> toggleFavoritePhoto(String id) async {
    final res = await _dio.put<Map<String, dynamic>>('/photos/$id/favorite');
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> listPhotoLocations() async {
    final res = await _dio.get<List<dynamic>>('/photos/locations');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<int> batchFavoritePhotos(List<String> ids, bool value) async {
    final res = await _dio.post<int>(
      '/photos/batch/favorite',
      data: {'ids': ids, 'value': value},
    );
    return res.data!;
  }

  Future<int> batchDeletePhotos(List<String> ids) async {
    final res = await _dio.post<int>(
      '/photos/batch/delete',
      data: {'ids': ids},
    );
    return res.data!;
  }

  Future<int> batchAddToAlbum(String albumId, List<String> photoIds) async {
    final res = await _dio.post<int>(
      '/photos/batch/album',
      data: {'ids': photoIds, 'album_id': albumId},
    );
    return res.data!;
  }

  String originalUrl(String photoId) {
    final url = '$baseUrl/api/v1/photos/$photoId';
    return token != null ? '$url?token=$token' : url;
  }

  // Search
  Future<List<Map<String, dynamic>>> searchPhotos(String query, {int limit = 20}) async {
    final res = await _dio.get<List<dynamic>>(
      '/photos/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    return res.data!.cast<Map<String, dynamic>>();
  }

  // Tags
  Future<List<Map<String, dynamic>>> getPhotoTags(String photoId) async {
    final res = await _dio.get<List<dynamic>>('/photos/$photoId/tags');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<void> addPhotoTag(String photoId, String name) async {
    await _dio.post<void>('/photos/$photoId/tags', data: {'name': name});
  }

  Future<void> removePhotoTag(String photoId, int tagId) async {
    await _dio.delete<void>('/photos/$photoId/tags/$tagId');
  }

  // Faces
  Future<List<Map<String, dynamic>>> listFaceClusters() async {
    final res = await _dio.get<List<dynamic>>('/photos/faces');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> clusterPhotos(int clusterId) async {
    final res = await _dio.get<List<dynamic>>('/photos/faces/$clusterId/photos');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<void> setClusterLabel(int clusterId, String label) async {
    await _dio.put<void>('/photos/faces/$clusterId/label', data: {'label': label});
  }

  // Stats
  Future<Map<String, dynamic>> getStats() async {
    final res = await _dio.get<Map<String, dynamic>>('/stats');
    return res.data!;
  }

  // Files
  Future<List<Map<String, dynamic>>> listFiles({String? parentId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/files',
      queryParameters: {if (parentId != null) 'parent_id': parentId},
    );
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> uploadFile(Uint8List data, String filename, {String? parentId}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(data, filename: filename),
      if (parentId != null) 'parent_id': parentId,
    });
    final res = await _dio.post<Map<String, dynamic>>('/files/upload', data: formData);
    return res.data!;
  }

  Future<Map<String, dynamic>> createFolder(String name, {String? parentId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/files/folder',
      data: {'name': name, if (parentId != null) 'parent_id': parentId},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> renameFile(String id, String newName) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/files/$id/rename',
      data: {'name': newName},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> moveFile(String id, {String? parentId}) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/files/$id/move',
      data: {'parent_id': parentId},
    );
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> searchFiles(String query) async {
    final res = await _dio.get<List<dynamic>>(
      '/files/search',
      queryParameters: {'q': query},
    );
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAncestors(String id) async {
    final res = await _dio.get<List<dynamic>>('/files/$id/ancestors');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<void> deleteFile(String id) async {
    await _dio.delete<void>('/files/$id');
  }

  Future<Map<String, dynamic>> toggleFavoriteFile(String id) async {
    final res = await _dio.put<Map<String, dynamic>>('/files/$id/favorite');
    return res.data!;
  }

  Future<void> downloadFile(String fileId, String savePath) async {
    await _dio.download('/files/$fileId', savePath);
  }

  String fileDownloadUrl(String fileId) {
    return '$baseUrl/api/v1/files/$fileId';
  }

  // Share links
  Future<Map<String, dynamic>> createShareLink(String fileId, {int? expiresHours}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/files/$fileId/share',
      data: {'expires_hours': expiresHours},
    );
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> listShareLinks(String fileId) async {
    final res = await _dio.get<List<dynamic>>('/files/$fileId/shares');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<void> deleteShareLink(String fileId, String shareId) async {
    await _dio.delete<void>('/files/$fileId/share/$shareId');
  }

  String shareUrl(String token) => '$baseUrl/s/$token';

  // Albums
  Future<List<Map<String, dynamic>>> listAlbums() async {
    final res = await _dio.get<List<dynamic>>('/albums');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createAlbum(String name) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/albums',
      data: {'name': name},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> updateAlbum(String id, String name) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/albums/$id',
      data: {'name': name},
    );
    return res.data!;
  }

  Future<void> deleteAlbum(String id) async {
    await _dio.delete<void>('/albums/$id');
  }

  Future<List<Map<String, dynamic>>> listAlbumPhotos(String albumId, {String? cursor, int limit = 50}) async {
    final res = await _dio.get<List<dynamic>>(
      '/albums/$albumId/photos',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<int> addPhotosToAlbum(String albumId, List<String> photoIds) async {
    final res = await _dio.post<int>(
      '/albums/$albumId/photos',
      data: {'photo_ids': photoIds},
    );
    return res.data!;
  }

  Future<void> removePhotoFromAlbum(String albumId, String photoId) async {
    await _dio.delete<void>('/albums/$albumId/photos/$photoId');
  }

  Future<Map<String, dynamic>> setAlbumCover(String albumId, String photoId) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/albums/$albumId/cover',
      data: {'photo_id': photoId},
    );
    return res.data!;
  }

  // Trash
  Future<Map<String, dynamic>> listTrash({String? cursor, int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/trash',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> restorePhoto(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/trash/photo/$id/restore');
    return res.data!;
  }

  Future<Map<String, dynamic>> restoreFile(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/trash/file/$id/restore');
    return res.data!;
  }

  Future<void> permanentDeletePhoto(String id) async {
    await _dio.delete<void>('/trash/photo/$id');
  }

  Future<void> permanentDeleteFile(String id) async {
    await _dio.delete<void>('/trash/file/$id');
  }

  Future<void> emptyTrash() async {
    await _dio.delete<void>('/trash/empty');
  }
}
