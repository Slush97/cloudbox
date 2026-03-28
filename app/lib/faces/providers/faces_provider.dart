import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';

final faceClustersProvider =
    StateNotifierProvider<FaceClustersNotifier, AsyncValue<List<FaceCluster>>>((ref) {
  final client = ref.watch(apiClientProvider);
  return FaceClustersNotifier(client)..load();
});

class FaceCluster {
  const FaceCluster({
    required this.clusterId,
    this.label,
    required this.faceCount,
    required this.samplePhotoIds,
  });

  factory FaceCluster.fromJson(Map<String, dynamic> json) => FaceCluster(
        clusterId: json['cluster_id'] as int,
        label: json['label'] as String?,
        faceCount: json['face_count'] as int,
        samplePhotoIds: (json['sample_photo_ids'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  final int clusterId;
  final String? label;
  final int faceCount;
  final List<String> samplePhotoIds;

  String? get samplePhotoId => samplePhotoIds.isNotEmpty ? samplePhotoIds.first : null;
}

class FaceClustersNotifier extends StateNotifier<AsyncValue<List<FaceCluster>>> {
  FaceClustersNotifier(this._client) : super(const AsyncValue.loading());

  final ApiClient _client;

  Future<void> load() async {
    try {
      final data = await _client.listFaceClusters();
      state = AsyncValue.data(data.map(FaceCluster.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
