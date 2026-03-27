import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Server'),
            subtitle: Text(auth.serverUrl ?? 'Not connected'),
          ),
          const Divider(),
          const _SectionHeader('Auto Upload'),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Auto-upload photos'),
            subtitle: const Text('Upload new camera photos automatically'),
            value: false, // TODO: persist setting
            onChanged: (v) {
              // TODO: toggle workmanager background task
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('Wi-Fi only'),
            subtitle: const Text('Only upload when connected to Wi-Fi'),
            value: true,
            onChanged: (v) {},
          ),
          const Divider(),
          const _SectionHeader('Storage'),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage used'),
            subtitle: Text('-- GB of -- GB'), // TODO: fetch from server
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
