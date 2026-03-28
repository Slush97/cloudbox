import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/client.dart';
import '../providers/map_provider.dart';

class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(photoLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: locations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (locs) {
          if (locs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No geotagged photos'),
                  SizedBox(height: 8),
                  Text('Photos with GPS data will appear here',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Center map on average position
          final avgLat = locs.map((l) => l.latitude).reduce((a, b) => a + b) / locs.length;
          final avgLng = locs.map((l) => l.longitude).reduce((a, b) => a + b) / locs.length;

          return _PhotoMap(
            locations: locs,
            center: LatLng(avgLat, avgLng),
          );
        },
      ),
    );
  }
}

class _PhotoMap extends ConsumerStatefulWidget {
  const _PhotoMap({required this.locations, required this.center});

  final List<PhotoLocation> locations;
  final LatLng center;

  @override
  ConsumerState<_PhotoMap> createState() => _PhotoMapState();
}

class _PhotoMapState extends ConsumerState<_PhotoMap> {
  String? _selectedPhotoId;

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(apiClientProvider);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: 4,
            onTap: (_, __) => setState(() => _selectedPhotoId = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cloudbox.app',
            ),
            MarkerLayer(
              markers: widget.locations.map((loc) {
                final isSelected = loc.id == _selectedPhotoId;
                return Marker(
                  point: LatLng(loc.latitude, loc.longitude),
                  width: isSelected ? 48 : 32,
                  height: isSelected ? 48 : 32,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPhotoId = loc.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(blurRadius: 4, color: Colors.black26),
                        ],
                      ),
                      child: Icon(
                        Icons.photo,
                        size: isSelected ? 24 : 16,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        if (_selectedPhotoId != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: CachedNetworkImage(
                          imageUrl: client.thumbnailUrl(_selectedPhotoId!, size: 'md'),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Tap thumbnail to view photo'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedPhotoId = null),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
