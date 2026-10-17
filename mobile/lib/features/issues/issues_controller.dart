import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/issue.dart';
import 'issues_repository.dart';

class IssuesController extends AsyncNotifier<List<Issue>> {
  @override
  FutureOr<List<Issue>> build() {
    return ref.watch(issuesRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(issuesRepositoryProvider).list());
  }

  Future<void> create(Map<String, dynamic> attrs) async {
    final repo = ref.read(issuesRepositoryProvider);
    final newItem = await repo.create(attrs);
    state = state.whenData((items) => [newItem, ...items]);
  }
}

final issuesControllerProvider =
    AsyncNotifierProvider<IssuesController, List<Issue>>(
  IssuesController.new,
);
