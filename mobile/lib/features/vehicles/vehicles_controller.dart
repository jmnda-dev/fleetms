import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/vehicle.dart';
import 'vehicles_repository.dart';

/// Exposes the vehicle list as async state. Screens `ref.watch` this; the
/// `AsyncNotifier` gives loading/error/data for free. This is the reference
/// controller — copy its shape for other list features.
class VehiclesController extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() {
    return ref.read(vehiclesRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ref.read(vehiclesRepositoryProvider).list);
  }
}

final vehiclesControllerProvider =
    AsyncNotifierProvider<VehiclesController, List<Vehicle>>(
        VehiclesController.new);

/// One vehicle by id (cache-backed via the repository). Used by the detail screen.
final vehicleDetailProvider = FutureProvider.family<Vehicle, String>((ref, id) {
  return ref.read(vehiclesRepositoryProvider).get(id);
});
