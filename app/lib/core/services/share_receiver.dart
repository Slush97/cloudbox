import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../api/client.dart';
import '../providers/auth_provider.dart';

/// Initializes the share receiver listener.
/// Call from main.dart after the app is running.
void initShareReceiver(WidgetRef ref, BuildContext context) {
  // Handle shared files when app is opened via share
  ReceiveSharingIntent.instance.getInitialMedia().then((files) {
    if (files.isNotEmpty) {
      _handleSharedFiles(ref, context, files);
    }
  });

  // Handle shared files when app is already running
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    if (files.isNotEmpty) {
      _handleSharedFiles(ref, context, files);
    }
  });
}

Future<void> _handleSharedFiles(
  WidgetRef ref,
  BuildContext context,
  List<SharedMediaFile> files,
) async {
  final auth = ref.read(authProvider);
  if (auth.token == null) return;

  final client = ref.read(apiClientProvider);
  var successCount = 0;
  var failCount = 0;

  for (final shared in files) {
    final path = shared.path;
    final file = File(path);
    if (!file.existsSync()) {
      failCount++;
      continue;
    }

    try {
      final bytes = await file.readAsBytes();
      final filename = path.split('/').last;
      final mimeType = shared.mimeType ?? '';

      if (mimeType.startsWith('image/') || mimeType.startsWith('video/')) {
        await client.uploadPhoto(bytes, filename);
      } else {
        await client.uploadFile(bytes, filename);
      }
      successCount++;
    } catch (_) {
      failCount++;
    }
  }

  if (context.mounted) {
    final msg = failCount > 0
        ? 'Uploaded $successCount, failed $failCount'
        : 'Uploaded $successCount file${successCount == 1 ? '' : 's'}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  ReceiveSharingIntent.instance.reset();
}
