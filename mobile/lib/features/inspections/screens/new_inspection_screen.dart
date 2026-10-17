import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../vehicles/vehicles_repository.dart';
import '../inspections_repository.dart';
import '../../vehicles/models/vehicle.dart';
import '../models/inspection_form_models.dart';

class NewInspectionScreen extends ConsumerStatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  ConsumerState<NewInspectionScreen> createState() =>
      _NewInspectionScreenState();
}

class _NewInspectionScreenState extends ConsumerState<NewInspectionScreen> {
  Vehicle? _selectedVehicle;
  InspectionForm? _selectedForm;

  List<Vehicle> _vehicles = [];
  List<InspectionForm> _forms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final vehiclesRepo = ref.read(vehiclesRepositoryProvider);
      final inspectionsRepo = ref.read(inspectionsRepositoryProvider);

      // Attempt to sync forms if online, but don't block on failure
      await inspectionsRepo.syncForms();

      final vehicles = await vehiclesRepo.list();
      final forms = await inspectionsRepo.getCachedForms();

      setState(() {
        _vehicles = vehicles;
        _forms = forms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  void _startInspection() async {
    if (_selectedVehicle == null || _selectedForm == null) return;

    final repo = ref.read(inspectionsRepositoryProvider);
    final latestVersion = await repo.getLatestCachedVersion(_selectedForm!.id);

    if (latestVersion == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not find version for this form.')));
      }
      return;
    }

    if (mounted) {
      context.push('/inspections/fill', extra: {
        'vehicle': _selectedVehicle,
        'formVersion': latestVersion,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Inspection')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New Inspection')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select Vehicle',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Vehicle>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              initialValue: _selectedVehicle,
              hint: const Text('Choose a vehicle...'),
              items: _vehicles.map((v) {
                return DropdownMenuItem(
                  value: v,
                  child: Text(v.name.isEmpty ? v.id : v.name),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedVehicle = v),
            ),
            const SizedBox(height: 24),
            const Text('Select Form',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<InspectionForm>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              initialValue: _selectedForm,
              hint: const Text('Choose an inspection form...'),
              items: _forms.where((f) => f.status == 'active').map((f) {
                return DropdownMenuItem(
                  value: f,
                  child: Text(f.title),
                );
              }).toList(),
              onChanged: (f) => setState(() => _selectedForm = f),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: (_selectedVehicle != null && _selectedForm != null)
                  ? _startInspection
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Start Inspection',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
