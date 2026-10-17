import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/fuel_log.dart';
import 'fuel_repository.dart';

class FuelController extends AsyncNotifier<List<FuelLog>> {
  @override
  FutureOr<List<FuelLog>> build() {
    return ref.watch(fuelRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(fuelRepositoryProvider).list());
  }

  Future<void> create(Map<String, dynamic> attrs) async {
    final repo = ref.read(fuelRepositoryProvider);
    final newItem = await repo.create(attrs);
    state = state.whenData((items) => [newItem, ...items]);
  }
}

final fuelControllerProvider =
    AsyncNotifierProvider<FuelController, List<FuelLog>>(
  FuelController.new,
);
