import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../vehicles/models/vehicle.dart';
import '../../vehicles/vehicles_controller.dart';
import '../issues_controller.dart';

/// Report a fault against a vehicle. The driver's core "do" action: pick the
/// vehicle, say what's wrong and how urgent. Works offline — the create falls
/// back to the outbox (see `IssuesRepository`).
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key, this.initialVehicleId});

  /// Preselect a vehicle (e.g. coming from a vehicle's detail screen).
  final String? initialVehicleId;

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  static const _priorities = ['None', 'Low', 'Medium', 'High'];

  String? _vehicleId;
  String _priority = 'Medium';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.initialVehicleId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await ref.read(issuesControllerProvider.notifier).create({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'priority': _priority,
        'vehicle_id': _vehicleId,
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Issue reported')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn\'t report issue: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Report issue')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            vehicles.when(
              loading: () => const _FieldSkeleton(label: 'Vehicle'),
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
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Brake squealing',
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Give the issue a title'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final p in _priorities)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What happened? Any detail helps the workshop.',
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 6,
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
                  : const Icon(Icons.send),
              label: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  const _FieldSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: const SizedBox(
        height: 20,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
