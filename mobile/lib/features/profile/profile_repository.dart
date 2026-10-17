import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/json_api.dart';
import 'models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  Future<UserProfile?> fetchProfile(String userId) async {
    final body = await _client.getMany('/user-profiles', query: {'filter[user_id]': userId});
    final items = JsonApi.many(body);
    if (items.isNotEmpty) {
      return UserProfile.fromJsonApi(items.first);
    }
    return null;
  }

  Future<UserProfile> createProfile(UserProfile profile) async {
    final body = JsonApi.body('user-profile', profile.toJsonApiAttributes());
    final res = await _client.post('/user-profiles', body);
    return UserProfile.fromJsonApi(JsonApi.one(res));
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final body = JsonApi.body('user-profile', profile.toJsonApiAttributes(), id: profile.id);
    final res = await _client.patch('/user-profiles/${profile.id}', body);
    return UserProfile.fromJsonApi(JsonApi.one(res));
  }
}

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(apiClientProvider)));
