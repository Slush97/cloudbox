import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/photos')) return 0;
    if (location.startsWith('/files')) return 1;
    if (location.startsWith('/faces')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => _navigate(context, i),
              destinations: _destinations
                  .map((d) => NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon,
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: _destinations,
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    const routes = ['/photos', '/files', '/faces', '/search', '/settings'];
    context.go(routes[index]);
  }
}

const _destinations = [
  NavigationDestination(
    icon: Icon(Icons.photo_library_outlined),
    selectedIcon: Icon(Icons.photo_library),
    label: 'Photos',
  ),
  NavigationDestination(
    icon: Icon(Icons.folder_outlined),
    selectedIcon: Icon(Icons.folder),
    label: 'Files',
  ),
  NavigationDestination(
    icon: Icon(Icons.face_outlined),
    selectedIcon: Icon(Icons.face),
    label: 'Faces',
  ),
  NavigationDestination(
    icon: Icon(Icons.search_outlined),
    selectedIcon: Icon(Icons.search),
    label: 'Search',
  ),
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];
