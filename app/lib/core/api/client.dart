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
  Future<String> login(String username, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return res.data!['token'] as String;
  }

  // Photos
  Future<List<Map<String, dynamic>>> listPhotos({String? cursor, int limit = 50}) async {
    final res = await _dio.get<List<dynamic>>(
      '/photos',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
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

  Future<void> deletePhoto(String id) async {
    await _dio.delete<void>('/photos/$id');
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

  // Faces
  Future<List<Map<String, dynamic>>> listFaceClusters() async {
    final res = await _dio.get<List<dynamic>>('/photos/faces');
    return res.data!.cast<Map<String, dynamic>>();
  }

  // Files
  Future<List<Map<String, dynamic>>> listFiles() async {
    final res = await _dio.get<List<dynamic>>('/files');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> uploadFile(Uint8List data, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(data, filename: filename),
    });
    final res = await _dio.post<Map<String, dynamic>>('/files/upload', data: formData);
    return res.data!;
  }

  Future<void> deleteFile(String id) async {
    await _dio.delete<void>('/files/$id');
  }

  String fileDownloadUrl(String fileId) {
    return '$baseUrl/api/v1/files/$fileId';
  }
}
