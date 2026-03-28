import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Extracts a user-friendly message from an exception.
String friendlyError(Object error) {
  if (error is DioException) {
    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'] as String;
      }
      if (response.statusCode == 401) return 'Session expired. Please log in again.';
      if (response.statusCode == 403) return 'Permission denied.';
      if (response.statusCode == 404) return 'Not found.';
      if (response.statusCode != null && response.statusCode! >= 500) {
        return 'Server error. Please try again later.';
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your network.';
      case DioExceptionType.connectionError:
        return 'Could not connect to server.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Network error. Please try again.';
    }
  }
  final msg = error.toString();
  // Strip "Exception: " prefix common in Dart
  if (msg.startsWith('Exception: ')) return msg.substring(11);
  return msg;
}

/// A centered error widget with icon, message, and optional retry button.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              friendlyError(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
