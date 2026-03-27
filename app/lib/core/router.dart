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
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/photos',
            builder: (context, state) => const GalleryPage(),
          ),
          GoRoute(
            path: '/files',
            builder: (context, state) => const FilesPage(),
          ),
          GoRoute(
            path: '/faces',
            builder: (context, state) => const FacesPage(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});
