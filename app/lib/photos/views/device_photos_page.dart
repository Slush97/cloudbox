import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/api/client.dart';
import '../providers/photos_provider.dart';
import '../widgets/date_scroller.dart';

class DevicePhotosPage extends ConsumerStatefulWidget {
  const DevicePhotosPage({super.key});

  @override
  ConsumerState<DevicePhotosPage> createState() => _DevicePhotosPageState();
}

class _DevicePhotosPageState extends ConsumerState<DevicePhotosPage> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _assets = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  int _uploadSkipped = 0;
  String? _error;
  final _scrollController = ScrollController();

  // Filter
  RequestType _requestType = RequestType.image;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() {
        _loading = false;
        _error = 'Photo library access denied. Grant permission in Settings.';
      });
      return;
    }
    await _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      hasAll: true,
      type: _requestType,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (albums.isEmpty) {
      setState(() {
        _albums = [];
        _currentAlbum = null;
        _assets = [];
        _loading = false;
      });
      return;
    }

    final defaultAlbum =
        albums.firstWhere((a) => a.isAll, orElse: () => albums.first);

    setState(() => _albums = albums);
    await _loadAlbumAssets(defaultAlbum);
  }

  Future<void> _loadAlbumAssets(AssetPathEntity album) async {
    setState(() {
      _currentAlbum = album;
      _loading = true;
      _selected.clear();
    });

    final count = await album.assetCountAsync;
    final assets = await album.getAssetListRange(start: 0, end: count);

    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  void _onTypeChanged(RequestType type) {
    setState(() {
      _requestType = type;
      _loading = true;
    });
    _loadAlbums();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selected.length == _assets.length) {
        _selected.clear();
      } else {
        _selected.addAll(_assets.map((a) => a.id));
      }
    });
  }

  Future<void> _uploadSelected() async {
    final toUpload =
        _assets.where((a) => _selected.contains(a.id)).toList();
    if (toUpload.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadSkipped = 0;
      _uploadTotal = toUpload.length;
    });

    final client = ref.read(apiClientProvider);

    for (final asset in toUpload) {
      if (!mounted) break;

      try {
        final Uint8List? bytes = await asset.originBytes;
        if (bytes == null) {
          setState(() => _uploadSkipped++);
          continue;
        }
        final filename = asset.title ?? '${asset.id}.jpg';
        await client.uploadPhoto(bytes, filename);
      } catch (e) {
        setState(() => _uploadSkipped++);
      }

      setState(() => _uploadDone++);
    }

    await ref.read(photosProvider.notifier).load();

    if (mounted) {
      final uploaded = _uploadDone - _uploadSkipped;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded $uploaded photo${uploaded == 1 ? '' : 's'}'
            '${_uploadSkipped > 0 ? ' ($_uploadSkipped skipped)' : ''}',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _selected.length == _assets.length && _assets.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _selected.isEmpty
            ? _buildAlbumDropdown()
            : Text('${_selected.length} selected'),
        actions: [
          // Type filter
          PopupMenuButton<RequestType>(
            icon: const Icon(Icons.filter_list),
            onSelected: _onTypeChanged,
            itemBuilder: (_) => [
              _typeItem(RequestType.image, 'Photos', Icons.photo),
              _typeItem(RequestType.video, 'Videos', Icons.videocam),
              _typeItem(RequestType.common, 'All media', Icons.perm_media),
            ],
          ),
          if (_assets.isNotEmpty)
            TextButton(
              onPressed: _uploading ? null : _selectAll,
              child: Text(allSelected ? 'Deselect all' : 'Select all'),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _selected.isNotEmpty && !_uploading
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton.icon(
                  onPressed: _uploadSelected,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text('Upload ${_selected.length} photo'
                      '${_selected.length == 1 ? '' : 's'}'),
                ),
              ),
            )
          : null,
    );
  }

  PopupMenuItem<RequestType> _typeItem(
      RequestType type, String label, IconData icon) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
          if (_requestType == type) ...[
            const Spacer(),
            Icon(Icons.check,
                size: 18, color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildAlbumDropdown() {
    if (_albums.isEmpty || _currentAlbum == null) {
      return const Text('Camera Roll');
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _currentAlbum!.id,
        isDense: true,
        items: _albums
            .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (id) {
          if (id == null) return;
          final album = _albums.firstWhere((a) => a.id == id);
          _loadAlbumAssets(album);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_assets.isEmpty) {
      return const Center(child: Text('No photos found.'));
    }

    if (_uploading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _uploadTotal > 0 ? _uploadDone / _uploadTotal : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Uploading $_uploadDone / $_uploadTotal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_uploadSkipped > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$_uploadSkipped skipped (duplicates)',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final groups = groupByMonth(_assets, (a) => a.createDateTime);
    final sections = buildSections(groups);
    final crossAxisCount =
        MediaQuery.sizeOf(context).width >= 800 ? 5 : 3;

    return DateScroller(
      controller: _scrollController,
      sectionKeys: sections,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final (label, items) in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final asset = items[index];
                  final selected = _selected.contains(asset.id);

                  return GestureDetector(
                    onTap: () => _toggleSelect(asset.id),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _AssetThumbnail(asset: asset),
                        if (selected)
                          ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white70,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({required this.asset});
  final AssetEntity asset;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(240),
      format: ThumbnailFormat.jpeg,
      quality: 80,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
    }
    return Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
