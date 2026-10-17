import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/offline/outbox_sync_service.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'routing/router.dart';

/// Root widget: Material 3 app driven by the go_router in [routerProvider].
/// Themed from [FleetmsTheme], which mirrors the web app's color tokens; follows
/// the device light/dark setting.
class FleetmsApp extends ConsumerWidget {
  const FleetmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Flush any queued offline writes once we're authenticated. Reading the
    // provider also constructs the service, which then listens for connectivity
    // regain and flushes again on its own.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        ref.read(outboxSyncServiceProvider).syncOutbox();
      }
    });

    return MaterialApp.router(
      title: 'FleetMS',
      debugShowCheckedModeBanner: false,
      theme: FleetmsTheme.light,
      darkTheme: FleetmsTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
