import 'dart:async';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/client.dart';
import '../../core/models/file_entry.dart';
import '../providers/files_provider.dart';

class FilesPage extends ConsumerWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filesProvider);
    final currentFolder = ref.watch(currentFolderProvider);

    return Scaffold(
      appBar: AppBar(
        title: currentFolder == null
            ? const Text('Files')
            : _BreadcrumbBar(folderId: currentFolder),
        leading: currentFolder != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goUp(ref, currentFolder),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
          ),
        ],
      ),
      body: files.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
                child: Text('Empty folder. Tap + to add files.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(filesProvider.notifier).load(),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) =>
                  _FileTile(file: list[index]),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'new_folder',
            onPressed: () => _createFolder(context, ref),
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'upload_file',
            onPressed: () => _pickAndUpload(ref),
            child: const Icon(Icons.upload_file),
          ),
        ],
      ),
    );
  }

  Future<void> _goUp(WidgetRef ref, String currentFolder) async {
    final client = ref.read(apiClientProvider);
    try {
      final ancestors = await client.getAncestors(currentFolder);
      final entries = ancestors.map(FileEntry.fromJson).toList();
      // entries are root-first. The second-to-last is the parent.
      // If only 1 entry (the folder itself), go to root.
      if (entries.length <= 1) {
        ref.read(currentFolderProvider.notifier).state = null;
      } else {
        // The last entry is the current folder, second-to-last is parent
        ref.read(currentFolderProvider.notifier).state =
            entries[entries.length - 2].id;
      }
    } catch (_) {
      ref.read(currentFolderProvider.notifier).state = null;
    }
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(filesProvider.notifier).createFolder(name);
    }
  }

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    final notifier = ref.read(filesProvider.notifier);
    for (final file in result.files) {
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes != null) {
        await notifier.upload(bytes, file.name);
      }
    }
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _FileSearchDelegate(ref),
    );
  }
}

// ---- Breadcrumb bar ----

class _BreadcrumbBar extends ConsumerStatefulWidget {
  const _BreadcrumbBar({required this.folderId});
  final String folderId;

  @override
  ConsumerState<_BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends ConsumerState<_BreadcrumbBar> {
  late Future<List<Map<String, dynamic>>> _ancestorsFuture;

  @override
  void initState() {
    super.initState();
    _ancestorsFuture = ref.read(apiClientProvider).getAncestors(widget.folderId);
  }

  @override
  void didUpdateWidget(_BreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId != widget.folderId) {
      _ancestorsFuture = ref.read(apiClientProvider).getAncestors(widget.folderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ancestorsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Files');
        final ancestors =
            snapshot.data!.map(FileEntry.fromJson).toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              GestureDetector(
                onTap: () =>
                    ref.read(currentFolderProvider.notifier).state = null,
                child: Text('Files',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
              ),
              for (final entry in ancestors) ...[
                const Text(' / '),
                GestureDetector(
                  onTap: () => ref
                      .read(currentFolderProvider.notifier)
                      .state = entry.id,
                  child: Text(
                    entry.filename,
                    style: entry.id == widget.folderId
                        ? null
                        : TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---- File tile ----

class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file});
  final FileEntry file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat.yMd().add_jm();

    return ListTile(
      leading: Icon(file.icon,
          color: file.isFolder
              ? Theme.of(context).colorScheme.primary
              : null),
      title: Text(file.filename, overflow: TextOverflow.ellipsis),
      subtitle: file.isFolder
          ? null
          : Text(
              '${file.humanSize}  -  ${dateFormat.format(file.updatedAt)}'),
      onTap: file.isFolder
          ? () =>
              ref.read(currentFolderProvider.notifier).state = file.id
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (file.isFavorited)
            const Icon(Icons.favorite, size: 18, color: Colors.red),
          PopupMenuButton<String>(
            onSelected: (action) =>
                _onAction(action, context, ref),
            itemBuilder: (context) => [
              if (!file.isFolder)
                const PopupMenuItem(
                    value: 'download', child: Text('Download')),
              if (!file.isFolder)
                const PopupMenuItem(
                    value: 'share', child: Text('Share link')),
              PopupMenuItem(
                  value: 'favorite',
                  child: Text(file.isFavorited ? 'Unfavorite' : 'Favorite')),
              const PopupMenuItem(
                  value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'move', child: Text('Move to...')),
              const PopupMenuItem(value: 'delete', child: Text('Move to trash')),
            ],
          ),
        ],
      ),
    );
  }

  void _onAction(String action, BuildContext context, WidgetRef ref) {
    switch (action) {
      case 'download':
        _download(context, ref);
      case 'share':
        _share(context, ref);
      case 'favorite':
        _toggleFavorite(ref);
      case 'rename':
        _rename(context, ref);
      case 'move':
        _moveDialog(context, ref);
      case 'delete':
        _confirmDelete(context, ref);
    }
  }

  Future<void> _toggleFavorite(WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    await client.toggleFavoriteFile(file.id);
    await ref.read(filesProvider.notifier).load();
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);

    // Ask for expiry
    final expiresHours = await showDialog<int?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Share link expiry'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(-1),
            child: const Text('No expiry'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(1),
            child: const Text('1 hour'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(24),
            child: const Text('1 day'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(24 * 7),
            child: const Text('1 week'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(24 * 30),
            child: const Text('30 days'),
          ),
        ],
      ),
    );

    if (expiresHours == null) return;

    try {
      final link = await client.createShareLink(
        file.id,
        expiresHours: expiresHours == -1 ? null : expiresHours,
      );
      final token = link['token'] as String;
      final url = client.shareUrl(token);

      await Clipboard.setData(ClipboardData(text: url));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Link copied: $url')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create share link: $e')),
        );
      }
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: file.filename);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != file.filename) {
      await ref.read(filesProvider.notifier).rename(file.id, newName);
    }
  }

  Future<void> _moveDialog(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    String? targetParentId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _MoveFolderPicker(
        client: client,
        excludeId: file.id,
        onSelect: (id) => targetParentId = id,
      ),
    );

    if (confirmed == true) {
      await ref
          .read(filesProvider.notifier)
          .move(file.id, targetParentId: targetParentId);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final label = file.isFolder ? 'folder' : 'file';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move $label to trash?'),
        content: Text(
            '"${file.filename}"${file.isFolder ? ' and all its contents' : ''} will be permanently deleted after 30 days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Move to trash',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(filesProvider.notifier).delete(file.id);
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${file.filename}';
      await client.downloadFile(file.id, path);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}

// ---- Move folder picker dialog ----

class _MoveFolderPicker extends StatefulWidget {
  const _MoveFolderPicker({
    required this.client,
    required this.excludeId,
    required this.onSelect,
  });

  final ApiClient client;
  final String excludeId;
  final ValueChanged<String?> onSelect;

  @override
  State<_MoveFolderPicker> createState() => _MoveFolderPickerState();
}

class _MoveFolderPickerState extends State<_MoveFolderPicker> {
  final List<String?> _parentHistory = [null]; // stack: root is null
  String? get _currentParent => _parentHistory.last;
  List<FileEntry> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    final data =
        await widget.client.listFiles(parentId: _currentParent);
    final entries = data
        .map(FileEntry.fromJson)
        .where((f) => f.isFolder && f.id != widget.excludeId)
        .toList();
    setState(() {
      _folders = entries;
      _loading = false;
    });
  }

  void _goUp() {
    if (_parentHistory.length > 1) {
      _parentHistory.removeLast();
      _loadFolders();
    }
  }

  void _goInto(String folderId) {
    _parentHistory.add(folderId);
    _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move to...'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            if (_parentHistory.length > 1)
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Back'),
                onTap: _goUp,
              ),
            ListTile(
              leading: const Icon(Icons.check),
              title: Text(_currentParent == null
                  ? 'Move here (root)'
                  : 'Move here'),
              tileColor:
                  Theme.of(context).colorScheme.primaryContainer,
              onTap: () {
                widget.onSelect(_currentParent);
                Navigator.of(context).pop(true);
              },
            ),
            const Divider(),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _folders.isEmpty
                    ? const Center(child: Text('No subfolders'))
                    : ListView.builder(
                        itemCount: _folders.length,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(folder.filename),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _goInto(folder.id),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ---- File search delegate ----

class _FileSearchDelegate extends SearchDelegate<void> {
  _FileSearchDelegate(this._ref);
  final WidgetRef _ref;

  Timer? _debounce;
  String _lastQuery = '';
  Future<List<Map<String, dynamic>>>? _resultsFuture;

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          _debounce?.cancel();
          close(context, null);
        },
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 2) {
      return const Center(child: Text('Type to search files...'));
    }

    if (query != _lastQuery) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _lastQuery = query;
        _resultsFuture = _ref.read(apiClientProvider).searchFiles(query);
        // Trigger rebuild by showing results
        showResults(context);
      });
      // While debouncing, show previous results or loading
      if (_resultsFuture == null) {
        return const Center(child: CircularProgressIndicator());
      }
    }

    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.length < 2) {
      return const Center(child: Text('Type to search files...'));
    }

    // Ensure we have a future for the current query
    if (_lastQuery != query) {
      _lastQuery = query;
      _resultsFuture = _ref.read(apiClientProvider).searchFiles(query);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final results =
            (snapshot.data ?? []).map(FileEntry.fromJson).toList();
        if (results.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final file = results[index];
            return ListTile(
              leading: Icon(file.icon),
              title: Text(file.filename),
              subtitle: file.isFolder ? null : Text(file.humanSize),
              onTap: () {
                _debounce?.cancel();
                if (file.isFolder) {
                  _ref.read(currentFolderProvider.notifier).state =
                      file.id;
                } else if (file.parentId != null) {
                  _ref.read(currentFolderProvider.notifier).state =
                      file.parentId;
                } else {
                  _ref.read(currentFolderProvider.notifier).state =
                      null;
                }
                close(context, null);
              },
            );
          },
        );
      },
    );
  }
}
