import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/demo_store.dart';
import 'providers/app_providers.dart';

class CourtFlowApp extends ConsumerWidget {
  const CourtFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 2 bridge: mirror the Firebase session into the demo store so the
    // existing booking screens keep working until Phase 3 moves them to
    // Firestore streams.
    ref.listen(currentUserProvider, (previous, next) {
      if (!AppConfig.useFirebase) return;
      ref.read(demoStoreProvider.notifier).setUser(next);
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CourtFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
