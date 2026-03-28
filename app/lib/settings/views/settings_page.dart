import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/auto_upload_provider.dart';
import '../../core/theme.dart';
import '../../trash/views/trash_page.dart';

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
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Pair new device'),
            subtitle: const Text('Show QR code to connect another phone'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('${auth.serverUrl}/pair'),
              mode: LaunchMode.externalApplication,
            ),
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
          const _SectionHeader('Auto-Upload'),
          _AutoUploadSection(),
          const Divider(),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Trash'),
            subtitle: const Text('View and restore deleted items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TrashPage()),
            ),
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

class _AutoUploadSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(autoUploadProvider);
    final dateFormat = DateFormat.yMd().add_jm();

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Auto-upload photos'),
          subtitle: const Text('Upload new photos from camera roll'),
          value: state.enabled,
          onChanged: (v) =>
              ref.read(autoUploadProvider.notifier).setEnabled(v),
        ),
        if (state.enabled) ...[
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('WiFi only'),
            value: state.wifiOnly,
            onChanged: (v) =>
                ref.read(autoUploadProvider.notifier).setWifiOnly(v),
          ),
          ListTile(
            leading: state.uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: state.lastSync != null
                ? Text('Last sync: ${dateFormat.format(state.lastSync!)}')
                : const Text('Never synced'),
            onTap: state.uploading
                ? null
                : () async {
                    final count = await ref
                        .read(autoUploadProvider.notifier)
                        .syncNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Uploaded $count new photos')),
                      );
                    }
                  },
          ),
        ],
      ],
    );
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
