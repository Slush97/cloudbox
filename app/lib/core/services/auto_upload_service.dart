import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/client.dart';

class AutoUploadService {
  AutoUploadService(this._client);

  final ApiClient _client;

  static const _lastSyncKey = 'auto_upload_last_sync';
  static const _enabledKey = 'auto_upload_enabled';
  static const _wifiOnlyKey = 'auto_upload_wifi_only';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  static Future<bool> isWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wifiOnlyKey) ?? true;
  }

  static Future<void> setWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
  }

  static Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSyncKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Run the sync — upload new photos since last sync.
  /// Returns the number of photos uploaded.
  Future<int> sync() async {
    final enabled = await isEnabled();
    if (!enabled) return 0;

    // Check connectivity
    final wifiOnly = await isWifiOnly();
    if (wifiOnly) {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.wifi)) {
        return 0;
      }
    }

    // Get permission
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return 0;

    // Determine time range
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMs = prefs.getInt(_lastSyncKey);
    final filterOption = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: lastSyncMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
            : DateTime(2000),
        max: DateTime.now(),
      ),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: filterOption,
    );

    var uploadCount = 0;
    for (final album in albums) {
      final assets = await album.getAssetListRange(start: 0, end: 500);
      for (final asset in assets) {
        try {
          final file = await asset.originFile;
          if (file == null) continue;

          final bytes = await file.readAsBytes();
          final filename = await asset.titleAsync;

          await _client.uploadPhoto(Uint8List.fromList(bytes), filename);
          uploadCount++;
        } catch (_) {
          // Server returns duplicate error for already-uploaded photos — skip
          continue;
        }
      }
    }

    // Update last sync time
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    return uploadCount;
  }
}
