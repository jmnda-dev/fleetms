import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/status_chip.dart';
import '../models/vehicle.dart';
import '../vehicles_controller.dart';

/// A vehicle's detail, with quick actions for the things a driver does against
/// it: report an issue, log fuel, start an inspection (the first two preselect
/// this vehicle).
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle')),
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$err', textAlign: TextAlign.center),
        )),
        data: (v) => _Body(vehicle: v),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                vehicle.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (vehicle.status != null) StatusChip(vehicle.status!),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _DetailRow(label: 'License plate', value: vehicle.licensePlate),
              _DetailRow(label: 'Type', value: vehicle.type),
              _DetailRow(label: 'Body style', value: vehicle.bodyStyle),
              _DetailRow(label: 'Year', value: vehicle.year?.toString()),
              _DetailRow(label: 'Colour', value: vehicle.color),
              _DetailRow(
                label: 'Mileage',
                value: vehicle.mileage == null ? null : '${vehicle.mileage} km',
              ),
              _DetailRow(label: 'VIN', value: vehicle.vin),
              _DetailRow(label: 'Model code', value: vehicle.modelCode),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => context
                  .push('/issues/new', extra: {'vehicle_id': vehicle.id}),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report issue'),
            ),
            FilledButton.tonalIcon(
              onPressed: () =>
                  context.push('/fuel/new', extra: {'vehicle_id': vehicle.id}),
              icon: const Icon(Icons.local_gas_station_outlined),
              label: const Text('Log fuel'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/inspections/new'),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Inspect'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value!, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
