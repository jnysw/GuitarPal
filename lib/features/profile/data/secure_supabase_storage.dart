import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureSupabaseLocalStorage extends LocalStorage {
  const SecureSupabaseLocalStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const _sessionKey = 'guitarpal.supabase.session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}

class SecureSupabasePkceStorage extends GotrueAsyncStorage {
  const SecureSupabasePkceStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const _keyPrefix = 'guitarpal.supabase.pkce.';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) {
    return _storage.read(key: '$_keyPrefix$key');
  }

  @override
  Future<void> setItem({required String key, required String value}) {
    return _storage.write(key: '$_keyPrefix$key', value: value);
  }

  @override
  Future<void> removeItem({required String key}) {
    return _storage.delete(key: '$_keyPrefix$key');
  }
}
