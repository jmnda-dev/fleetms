import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'models/user_profile.dart';
import 'profile_repository.dart';

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final authStatus = ref.watch(authControllerProvider);
  if (authStatus.status != AuthStatus.authenticated || authStatus.userId == null) {
    return null;
  }

  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchProfile(authStatus.userId!);
});

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(this._repo, AsyncValue<UserProfile?> state)
      : super(state);

  final ProfileRepository _repo;

  Future<void> saveProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    try {
      UserProfile updated;
      if (profile.id.isEmpty) {
        updated = await _repo.createProfile(profile);
      } else {
        updated = await _repo.updateProfile(profile);
      }
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
  final state = ref.watch(profileProvider);
  return ProfileController(ref.watch(profileRepositoryProvider), state);
});
