import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme.dart';

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
    final themeMode = ref.watch(themeModeProvider);
    final colors = Theme.of(context).colorScheme;

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
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                ref.read(themeModeProvider.notifier).set(selected.first);
              },
              showSelectedIcon: false,
            ),
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
            leading: Icon(Icons.logout, color: colors.error),
            title: Text('Log out', style: TextStyle(color: colors.error)),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
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
