import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/providers/auth_provider.dart';

final _statsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.getStats();
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final stats = ref.watch(_statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Server'),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Connected to'),
            subtitle: Text(auth.serverUrl ?? 'Not connected'),
          ),
          const Divider(),
          const _SectionHeader('Storage'),
          stats.when(
            loading: () => const ListTile(
              leading: Icon(Icons.storage_outlined),
              title: Text('Storage used'),
              subtitle: Text('Loading...'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.storage_outlined),
              title: Text('Storage used'),
              subtitle: Text('Could not load stats'),
            ),
            data: (data) {
              final bytes = data['storage_bytes'] as int? ?? 0;
              final photoCount = data['photo_count'] as int? ?? 0;
              final fileCount = data['file_count'] as int? ?? 0;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Storage used'),
                    subtitle: Text(_humanBytes(bytes)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Photos'),
                    subtitle: Text('$photoCount photos'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Files'),
                    subtitle: Text('$fileCount files'),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  static String _humanBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
