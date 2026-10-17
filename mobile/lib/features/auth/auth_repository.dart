import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'models/organization.dart';

/// The result of a successful sign-in: the bearer token and the orgs the user
/// can act in.
class SignInResult {
  const SignInResult({
    required this.token,
    required this.userId,
    required this.organizations,
  });

  final String token;
  final String userId;
  final List<Organization> organizations;
}

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<SignInResult> signIn(String email, String password) async {
    final body = await _client.signIn(email, password);
    final orgs = (body['organizations'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Organization.fromJson)
        .toList();

    return SignInResult(
      token: body['token'] as String,
      userId: (body['user_id'] ?? '') as String,
      organizations: orgs,
    );
  }

  Future<void> register(String email, String password) async {
    await _client.register(email, password);
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.requestPasswordReset(email);
  }

  Future<void> resetPassword(String token, String password) async {
    await _client.resetPassword(token, password);
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
