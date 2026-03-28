import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';

class PhotoLocation {
  const PhotoLocation({required this.id, required this.latitude, required this.longitude});

  factory PhotoLocation.fromJson(Map<String, dynamic> json) => PhotoLocation(
        id: json['id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  final String id;
  final double latitude;
  final double longitude;
}

final photoLocationsProvider =
    StateNotifierProvider<PhotoLocationsNotifier, AsyncValue<List<PhotoLocation>>>(
        (ref) {
  final client = ref.watch(apiClientProvider);
  return PhotoLocationsNotifier(client)..load();
});

class PhotoLocationsNotifier
    extends StateNotifier<AsyncValue<List<PhotoLocation>>> {
  PhotoLocationsNotifier(this._client) : super(const AsyncValue.loading());

  final ApiClient _client;

  Future<void> load() async {
    try {
      final data = await _client.listPhotoLocations();
      state = AsyncValue.data(data.map(PhotoLocation.fromJson).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
