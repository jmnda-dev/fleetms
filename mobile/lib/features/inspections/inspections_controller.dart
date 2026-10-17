import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/inspection.dart';
import 'inspections_repository.dart';

final archivedViewProvider = StateProvider<bool>((ref) => false);

class InspectionsController extends AsyncNotifier<List<Inspection>> {
  @override
  FutureOr<List<Inspection>> build() {
    final showArchived = ref.watch(archivedViewProvider);
    final repo = ref.watch(inspectionsRepositoryProvider);
    return showArchived ? repo.listArchived() : repo.list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final showArchived = ref.read(archivedViewProvider);
    final repo = ref.read(inspectionsRepositoryProvider);
    state = await AsyncValue.guard(() => showArchived ? repo.listArchived() : repo.list());
  }

  Future<void> create(Map<String, dynamic> attrs) async {
    final repo = ref.read(inspectionsRepositoryProvider);
    final newItem = await repo.create(attrs);
    if (!ref.read(archivedViewProvider)) {
      state = state.whenData((items) => [newItem, ...items]);
    }
  }

  Future<void> archive(String id) async {
    final repo = ref.read(inspectionsRepositoryProvider);
    await repo.archive(id);
    state = state.whenData((items) => items.where((i) => i.id != id).toList());
  }

  Future<void> restore(String id) async {
    final repo = ref.read(inspectionsRepositoryProvider);
    await repo.restore(id);
    state = state.whenData((items) => items.where((i) => i.id != id).toList());
  }
}

final inspectionsControllerProvider =
    AsyncNotifierProvider<InspectionsController, List<Inspection>>(
  InspectionsController.new,
);

final inspectionDetailProvider = FutureProvider.family<Inspection, String>((ref, id) async {
  return ref.watch(inspectionsRepositoryProvider).getById(id);
});
