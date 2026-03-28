import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../photos/views/gallery_page.dart';
import '../files/views/files_page.dart';
import '../faces/views/faces_page.dart';
import '../search/views/search_page.dart';
import '../settings/views/settings_page.dart';
import 'auth/login_page.dart';
import 'providers/auth_provider.dart';
import 'shell.dart';

final _shellNavigatorKeys = [
  GlobalKey<NavigatorState>(debugLabel: 'photos'),
  GlobalKey<NavigatorState>(debugLabel: 'files'),
  GlobalKey<NavigatorState>(debugLabel: 'faces'),
  GlobalKey<NavigatorState>(debugLabel: 'search'),
  GlobalKey<NavigatorState>(debugLabel: 'settings'),
];

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/photos',
    redirect: (context, state) {
      final loggedIn = auth.token != null;
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
                path: '/faces',
                builder: (context, state) => const FacesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys[3],
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys[4],
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
