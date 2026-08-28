import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  CredentialStore._();

  static final CredentialStore instance = CredentialStore._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _key(String deviceId, String name) => 'tv_remote.$deviceId.$name';

  Future<String?> read(String deviceId, String name) {
    return _storage.read(key: _key(deviceId, name));
  }

  Future<void> write(String deviceId, String name, String value) {
    return _storage.write(key: _key(deviceId, name), value: value);
  }

  Future<void> deleteDevice(String deviceId) async {
    final all = await _storage.readAll();
    final prefix = 'tv_remote.$deviceId.';
    for (final key in all.keys.where((key) => key.startsWith(prefix))) {
      await _storage.delete(key: key);
    }
  }
}
