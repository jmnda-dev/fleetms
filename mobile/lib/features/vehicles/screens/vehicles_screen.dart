import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/status_chip.dart';
import '../../auth/auth_controller.dart';
import '../vehicles_controller.dart';

/// The home screen once authenticated: the org's vehicles. Reference for how a
/// screen consumes an AsyncNotifier (loading / error / data) — copy this shape.
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(vehiclesControllerProvider.notifier).refresh(),
        child: vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _Error(
            message: '$err',
            onRetry: () =>
                ref.read(vehiclesControllerProvider.notifier).refresh(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _Centered(child: Text('No vehicles yet.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final v = list[i];
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/vehicles/${v.id}'),
                    title: Text(v.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle:
                        v.licensePlate != null ? Text(v.licensePlate!) : null,
                    trailing: v.status != null ? StatusChip(v.status!) : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Centered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Scrollable-centered so RefreshIndicator works even when content is short.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
              child: Padding(padding: const EdgeInsets.all(24), child: child)),
        ),
      ),
    );
  }
}
