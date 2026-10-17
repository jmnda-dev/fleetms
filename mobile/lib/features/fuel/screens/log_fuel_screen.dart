import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../vehicles/models/vehicle.dart';
import '../../vehicles/vehicles_controller.dart';
import '../fuel_controller.dart';

/// Log a refuel: vehicle, odometer, quantity and cost. The odometer matters —
/// it's what the fleet uses to work out fuel economy. Works offline via the
/// outbox fallback in `FuelRepository`.
class LogFuelScreen extends ConsumerStatefulWidget {
  const LogFuelScreen({super.key, this.initialVehicleId});

  /// Preselect a vehicle (e.g. coming from a vehicle's detail screen).
  final String? initialVehicleId;

  @override
  ConsumerState<LogFuelScreen> createState() => _LogFuelScreenState();
}

class _LogFuelScreenState extends ConsumerState<LogFuelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _quantity = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();

  // The app is Zambia-first; a per-org currency lookup can refine this later.
  static const _currency = 'ZMW';
  static const _fuelTypes = [
    'gasoline',
    'diesel',
    'electric',
    'hydrogen',
    'lpg',
    'other',
  ];

  String? _vehicleId;
  String _fuelType = 'diesel';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.initialVehicleId;
  }

  @override
  void dispose() {
    _odometer.dispose();
    _quantity.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return num.tryParse(v.trim()) == null ? 'Enter a number' : null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final attrs = <String, dynamic>{
        'vehicle_id': _vehicleId,
        'odometer': _odometer.text.trim(),
        'quantity': _quantity.text.trim(),
        'fuel_type': _fuelType,
        'refueled_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (_cost.text.trim().isNotEmpty) {
        attrs['cost'] = {'amount': _cost.text.trim(), 'currency': _currency};
      }
      if (_notes.text.trim().isNotEmpty) attrs['notes'] = _notes.text.trim();

      await ref.read(fuelControllerProvider.notifier).create(attrs);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fuel entry saved')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn\'t save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log fuel')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            vehicles.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Couldn\'t load vehicles: $err'),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _vehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: [
                  for (final Vehicle v in list)
                    DropdownMenuItem(value: v.id, child: Text(v.name)),
                ],
                validator: (v) => v == null ? 'Choose a vehicle' : null,
                onChanged: (v) => setState(() => _vehicleId = v),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _odometer,
              decoration: const InputDecoration(
                labelText: 'Odometer (km)',
                helperText: 'Needed to work out fuel economy',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _requiredNumber,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(labelText: 'Quantity (litres)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _requiredNumber,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cost,
              decoration: const InputDecoration(
                labelText: 'Cost',
                prefixText: '$_currency ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return num.tryParse(v.trim()) == null ? 'Enter a number' : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _fuelType,
              decoration: const InputDecoration(labelText: 'Fuel type'),
              items: [
                for (final t in _fuelTypes)
                  DropdownMenuItem(value: t, child: Text(_titleCase(t))),
              ],
              onChanged: (v) => setState(() => _fuelType = v ?? 'diesel'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
