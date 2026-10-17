import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the auth token and the selected organization's `public_id` in the
/// platform secure store, so a session survives app restarts.
class SecureStore {
  SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'fleetms.token';
  static const _orgKey = 'fleetms.org_public_id';
  static const _userKey = 'fleetms.user_id';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readOrg() => _storage.read(key: _orgKey);
  Future<String?> readUserId() => _storage.read(key: _userKey);

  Future<void> writeSession({required String token, required String userId, String? orgPublicId}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userId);
    if (orgPublicId != null) {
      await _storage.write(key: _orgKey, value: orgPublicId);
    }
  }

  Future<void> writeOrg(String orgPublicId) =>
      _storage.write(key: _orgKey, value: orgPublicId);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _orgKey);
    await _storage.delete(key: _userKey);
  }
}

final secureStoreProvider = Provider<SecureStore>(
  (ref) => SecureStore(const FlutterSecureStorage()),
);
