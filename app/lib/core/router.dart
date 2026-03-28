import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../albums/views/albums_page.dart';
import '../map/views/map_page.dart';
import '../photos/views/gallery_page.dart';
import '../files/views/files_page.dart';
import '../settings/views/settings_page.dart';
import '../trash/views/trash_page.dart';
import 'auth/login_page.dart';
import 'providers/auth_provider.dart';
import 'shell.dart';

final _shellNavigatorKeys = [
  GlobalKey<NavigatorState>(debugLabel: 'photos'),
  GlobalKey<NavigatorState>(debugLabel: 'files'),
  GlobalKey<NavigatorState>(debugLabel: 'map'),
  GlobalKey<NavigatorState>(debugLabel: 'settings'),
];

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/photos',
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final loggedIn = auth.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/photos';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/albums',
        builder: (context, state) => const AlbumsPage(),
      ),
      GoRoute(
        path: '/trash',
        builder: (context, state) => const TrashPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys[0],
            routes: [
              GoRoute(
                path: '/photos',
                builder: (context, state) => const GalleryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys[1],
            routes: [
              GoRoute(
                path: '/files',
                builder: (context, state) => const FilesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys[2],
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys[3],
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
