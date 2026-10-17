import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/secure_store.dart';
import 'auth_repository.dart';
import 'models/organization.dart';

enum AuthStatus { unknown, unauthenticated, needsOrg, authenticated }

/// The whole auth state the router and screens react to. Deliberately a plain
/// immutable class (no codegen).
class AuthState {
  const AuthState({
    required this.status,
    this.organizations = const [],
    this.orgPublicId,
    this.userId,
    this.error,
    this.busy = false,
  });

  final AuthStatus status;
  final List<Organization> organizations; // populated when status == needsOrg
  final String? orgPublicId; // the chosen tenant, when authenticated
  final String? userId;
  final String? error;
  final bool busy;

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);

  AuthState copyWith({
    AuthStatus? status,
    List<Organization>? organizations,
    String? orgPublicId,
    String? userId,
    String? error,
    bool? busy,
  }) =>
      AuthState(
        status: status ?? this.status,
        organizations: organizations ?? this.organizations,
        orgPublicId: orgPublicId ?? this.orgPublicId,
        userId: userId ?? this.userId,
        error: error,
        busy: busy ?? this.busy,
      );
}

/// Owns sign-in, org selection, bootstrap-from-storage and sign-out, and keeps
/// the [ApiClient]'s token + tenant in sync with the current session.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _bootstrap();
    return const AuthState.unknown();
  }

  SecureStore get _store => ref.read(secureStoreProvider);
  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _bootstrap() async {
    final token = await _store.readToken();
    final org = await _store.readOrg();
    final userId = await _store.readUserId();
    if (token != null && org != null && userId != null) {
      _api.setSession(token: token, orgPublicId: org);
      state = AuthState(status: AuthStatus.authenticated, orgPublicId: org, userId: userId);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await ref.read(authRepositoryProvider).signIn(email, password);
      _api.setSession(token: result.token);
      await _store.writeSession(token: result.token, userId: result.userId);

      switch (result.organizations.length) {
        case 0:
          state = const AuthState.unauthenticated(
            error: "You're not a member of any organization.",
          );
        case 1:
          await _selectOrg(result.organizations.first);
        default:
          state = AuthState(
            status: AuthStatus.needsOrg,
            organizations: result.organizations,
            userId: result.userId,
          );
      }
    } on ApiException catch (e) {
      state = AuthState.unauthenticated(error: e.message);
    }
  }

  Future<void> register(String email, String password) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await ref.read(authRepositoryProvider).register(email, password);
      state = state.copyWith(busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      state = state.copyWith(busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      rethrow;
    }
  }

  Future<void> resetPassword(String token, String password) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await ref.read(authRepositoryProvider).resetPassword(token, password);
      state = state.copyWith(busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      rethrow;
    }
  }

  Future<void> selectOrg(Organization org) => _selectOrg(org);

  Future<void> _selectOrg(Organization org) async {
    // The token was already set on the client and persisted during sign-in.
    _api.setOrg(org.publicId);
    await _store.writeOrg(org.publicId);
    final userId = await _store.readUserId();
    state = AuthState(status: AuthStatus.authenticated, orgPublicId: org.publicId, userId: userId);
  }

  Future<void> signOut() async {
    await _store.clear();
    _api.clearSession();
    state = const AuthState.unauthenticated();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
