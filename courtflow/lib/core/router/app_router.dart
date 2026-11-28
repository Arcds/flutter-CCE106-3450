import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../providers/backend_providers.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/player/club_discovery_screen.dart';
import '../../screens/player/club_storefront_screen.dart';
import '../../screens/player/my_passes_screen.dart';
import '../../screens/player/notifications_screen.dart';
import '../../screens/player/open_play_screen.dart';
import '../../screens/player/profile_settings_screen.dart';
import '../../screens/shell/app_shell.dart';
import '../../screens/staff/qr_scanner_screen.dart';
import '../../screens/staff/staff_control_center_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(
    currentUserProvider.select((user) => user?.uid),
    (_, _) => refresh.value++,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (!ref.read(authReadyProvider)) return null;
      final user = ref.read(currentUserProvider);
      final goingStaff = state.matchedLocation.startsWith('/staff');
      if (goingStaff && (user == null || !user.isStaff)) {
        final next = Uri.encodeComponent(state.uri.toString());
        return '/auth?next=$next';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const ClubDiscoveryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/open-play',
                builder: (context, state) => const OpenPlayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passes',
                builder: (context, state) => const MyPassesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/club/:facilityId',
        builder: (context, state) => ClubStorefrontScreen(
          facilityId: state.pathParameters['facilityId']!,
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffControlCenterScreen(),
        routes: [
          GoRoute(
            path: 'scan',
            builder: (context, state) => const QrScannerScreen(),
          ),
        ],
      ),
    ],
  );
});
