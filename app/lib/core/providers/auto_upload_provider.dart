import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../services/auto_upload_service.dart';

class AutoUploadState {
  const AutoUploadState({
    this.enabled = false,
    this.wifiOnly = true,
    this.lastSync,
    this.uploading = false,
  });

  final bool enabled;
  final bool wifiOnly;
  final DateTime? lastSync;
  final bool uploading;

  AutoUploadState copyWith({
    bool? enabled,
    bool? wifiOnly,
    DateTime? lastSync,
    bool? uploading,
  }) =>
      AutoUploadState(
        enabled: enabled ?? this.enabled,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        lastSync: lastSync ?? this.lastSync,
        uploading: uploading ?? this.uploading,
      );
}

final autoUploadProvider =
    StateNotifierProvider<AutoUploadNotifier, AutoUploadState>((ref) {
  final client = ref.watch(apiClientProvider);
  return AutoUploadNotifier(client)..init();
});

class AutoUploadNotifier extends StateNotifier<AutoUploadState> {
  AutoUploadNotifier(this._client) : super(const AutoUploadState());

  final ApiClient _client;

  Future<void> init() async {
    final enabled = await AutoUploadService.isEnabled();
    final wifiOnly = await AutoUploadService.isWifiOnly();
    final lastSync = await AutoUploadService.getLastSync();
    state = AutoUploadState(
      enabled: enabled,
      wifiOnly: wifiOnly,
      lastSync: lastSync,
    );
  }

  Future<void> setEnabled(bool value) async {
    await AutoUploadService.setEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setWifiOnly(bool value) async {
    await AutoUploadService.setWifiOnly(value);
    state = state.copyWith(wifiOnly: value);
  }

  Future<int> syncNow() async {
    state = state.copyWith(uploading: true);
    try {
      final service = AutoUploadService(_client);
      final count = await service.sync();
      final lastSync = await AutoUploadService.getLastSync();
      state = state.copyWith(uploading: false, lastSync: lastSync);
      return count;
    } catch (_) {
      state = state.copyWith(uploading: false);
      return 0;
    }
  }
}
