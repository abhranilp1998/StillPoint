import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stillpoint/src/services/security_service.dart';

void main() {
  test('pbkdf2 pin hashes verify against the same install salt', () async {
    final security = SecurityService(store: _MemoryStore());

    final hash = await security.hashPin('1234');
    final result = await security.verifyPin(pin: '1234', expectedHash: hash);

    expect(hash, startsWith('pbkdf2_sha256\$150000\$'));
    expect(result.matches, isTrue);
    expect(result.upgradedHash, isNull);
  });

  test('legacy pin hashes still unlock and return an upgraded hash', () async {
    final security = SecurityService(store: _MemoryStore());
    final legacyHash = sha256
        .convert(utf8.encode('stillpoint:1234'))
        .toString();

    final result = await security.verifyPin(
      pin: '1234',
      expectedHash: legacyHash,
    );

    expect(result.matches, isTrue);
    expect(result.upgradedHash, startsWith('pbkdf2_sha256\$150000\$'));
  });

  test('failed pin attempts add a persisted retry delay', () async {
    final store = _MemoryStore();
    final security = SecurityService(store: store);
    final hash = await security.hashPin('1234');

    await security.verifyPin(pin: '0000', expectedHash: hash);
    await security.verifyPin(pin: '0000', expectedHash: hash);
    final result = await security.verifyPin(pin: '0000', expectedHash: hash);

    expect(result.matches, isFalse);
    expect(result.retryAvailableAt, isNotNull);
    expect(result.retryAvailableAt!.isAfter(DateTime.now()), isTrue);

    final restored = SecurityService(store: store);
    final restoredRetry = await restored.currentRetryAvailableAt();
    expect(restoredRetry, isNotNull);
    expect(restoredRetry!.isAfter(DateTime.now()), isTrue);
  });
}

class _MemoryStore implements SecurityKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
