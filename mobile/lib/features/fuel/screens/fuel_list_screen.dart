import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../fuel_controller.dart';
import '../models/fuel_log.dart';

class FuelListScreen extends ConsumerWidget {
  const FuelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fuelControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(fuelControllerProvider.notifier).refresh(),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            message: '$err',
            onRetry: () => ref.read(fuelControllerProvider.notifier).refresh(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _Centered(
                child: Text('No fuel entries yet. Tap + to log one.'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: list.length,
              itemBuilder: (context, i) => _FuelTile(entry: list[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/fuel/new'),
        icon: const Icon(Icons.add),
        label: const Text('Log fuel'),
      ),
    );
  }
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({required this.entry});

  final FuelLog entry;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(entry.refueledAt);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_gas_station),
        title: Text(
          '${entry.quantity} L',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(date),
        trailing: Text(
          entry.costDisplay,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
  }
}
