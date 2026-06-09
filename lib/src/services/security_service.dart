import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

abstract class SecurityKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageKeyValueStore implements SecurityKeyValueStore {
  FlutterSecureStorageKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SecurityService {
  SecurityService({SecurityKeyValueStore? store})
    : _store = store ?? FlutterSecureStorageKeyValueStore();

  static const _installSaltKey = 'stillpoint_pin_salt_v1';
  static const _failedAttemptsKey = 'stillpoint_pin_failed_attempts_v1';
  static const _lockoutUntilKey = 'stillpoint_pin_lockout_until_v1';
  static const _pbkdf2Prefix = 'pbkdf2_sha256';
  static const _pbkdf2Iterations = 150000;
  static const _derivedKeyLength = 32;

  final SecurityKeyValueStore _store;

  String? _cachedInstallSalt;
  int? _cachedFailedAttempts;
  DateTime? _cachedRetryAvailableAt;

  bool isPinFormat(String pin) {
    return RegExp(r'^\d{4,8}$').hasMatch(pin);
  }

  Future<String> hashPin(String pin) async {
    final installSalt = await _loadOrCreateInstallSalt();
    final digest = _pbkdf2(
      password: utf8.encode(pin),
      salt: utf8.encode(installSalt),
      iterations: _pbkdf2Iterations,
      keyLength: _derivedKeyLength,
    );
    return [
      _pbkdf2Prefix,
      _pbkdf2Iterations.toString(),
      installSalt,
      base64UrlEncode(digest),
    ].join(r'$');
  }

  Future<PinVerificationResult> verifyPin({
    required String pin,
    required String expectedHash,
  }) async {
    final retryAvailableAt = await currentRetryAvailableAt();
    final now = DateTime.now();
    if (retryAvailableAt != null && retryAvailableAt.isAfter(now)) {
      return PinVerificationResult(
        matches: false,
        retryAvailableAt: retryAvailableAt,
      );
    }

    final parsedHash = _StoredPinHash.tryParse(expectedHash);
    final matches = switch (parsedHash) {
      _StoredPinHash() => _constantTimeEquals(
        _pbkdf2(
          password: utf8.encode(pin),
          salt: utf8.encode(parsedHash.salt),
          iterations: parsedHash.iterations,
          keyLength: _derivedKeyLength,
        ),
        base64Url.decode(parsedHash.digest),
      ),
      null => _legacyHash(pin) == expectedHash,
    };

    if (matches) {
      await clearFailedPinAttempts();
      return PinVerificationResult(
        matches: true,
        upgradedHash: parsedHash == null ? await hashPin(pin) : null,
      );
    }

    final failedAttempts = (await _loadFailedAttempts()) + 1;
    final delay = _delayForFailedAttempts(failedAttempts);
    final nextRetry = delay == Duration.zero ? null : now.add(delay);
    await _saveFailedAttemptState(
      failedAttempts: failedAttempts,
      retryAvailableAt: nextRetry,
    );
    return PinVerificationResult(matches: false, retryAvailableAt: nextRetry);
  }

  Future<DateTime?> currentRetryAvailableAt() async {
    if (_cachedRetryAvailableAt != null) {
      return _cachedRetryAvailableAt;
    }
    final raw = await _store.read(_lockoutUntilKey);
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    _cachedRetryAvailableAt = parsed;
    return parsed;
  }

  Future<void> clearFailedPinAttempts() async {
    _cachedFailedAttempts = 0;
    _cachedRetryAvailableAt = null;
    await _store.delete(_failedAttemptsKey);
    await _store.delete(_lockoutUntilKey);
  }

  Future<String> _loadOrCreateInstallSalt() async {
    if (_cachedInstallSalt != null) return _cachedInstallSalt!;

    var salt = await _store.read(_installSaltKey);
    if (salt == null || salt.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      salt = base64UrlEncode(bytes);
      await _store.write(_installSaltKey, salt);
    }
    _cachedInstallSalt = salt;
    return salt;
  }

  Future<int> _loadFailedAttempts() async {
    if (_cachedFailedAttempts != null) return _cachedFailedAttempts!;

    final raw = await _store.read(_failedAttemptsKey);
    final parsed = int.tryParse(raw ?? '') ?? 0;
    _cachedFailedAttempts = parsed;
    return parsed;
  }

  Future<void> _saveFailedAttemptState({
    required int failedAttempts,
    required DateTime? retryAvailableAt,
  }) async {
    _cachedFailedAttempts = failedAttempts;
    _cachedRetryAvailableAt = retryAvailableAt;
    await _store.write(_failedAttemptsKey, failedAttempts.toString());
    if (retryAvailableAt == null) {
      await _store.delete(_lockoutUntilKey);
      return;
    }
    await _store.write(_lockoutUntilKey, retryAvailableAt.toIso8601String());
  }

  Duration _delayForFailedAttempts(int failedAttempts) {
    if (failedAttempts < 3) return Duration.zero;
    return switch (failedAttempts) {
      3 => const Duration(seconds: 5),
      4 => const Duration(seconds: 15),
      5 => const Duration(seconds: 30),
      _ => const Duration(seconds: 60),
    };
  }

  static String _legacyHash(String pin) {
    return sha256.convert(utf8.encode('stillpoint:$pin')).toString();
  }

  static Uint8List _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    final blockCount = (keyLength / sha256.convert(const []).bytes.length)
        .ceil();
    final builder = BytesBuilder(copy: false);

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex += 1) {
      final blockSalt = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt);
      final blockView = ByteData.sublistView(blockSalt);
      blockView.setUint32(salt.length, blockIndex, Endian.big);

      var u = Uint8List.fromList(hmac.convert(blockSalt).bytes);
      final t = Uint8List.fromList(u);
      for (var iteration = 1; iteration < iterations; iteration += 1) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var index = 0; index < t.length; index += 1) {
          t[index] ^= u[index];
        }
      }
      builder.add(t);
    }

    final output = builder.takeBytes();
    return Uint8List.sublistView(output, 0, keyLength);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var index = 0; index < a.length; index += 1) {
      difference |= a[index] ^ b[index];
    }
    return difference == 0;
  }
}

class PinVerificationResult {
  const PinVerificationResult({
    required this.matches,
    this.retryAvailableAt,
    this.upgradedHash,
  });

  final bool matches;
  final DateTime? retryAvailableAt;
  final String? upgradedHash;
}

class _StoredPinHash {
  const _StoredPinHash({
    required this.iterations,
    required this.salt,
    required this.digest,
  });

  final int iterations;
  final String salt;
  final String digest;

  static _StoredPinHash? tryParse(String value) {
    final parts = value.split(r'$');
    if (parts.length != 4 || parts.first != SecurityService._pbkdf2Prefix) {
      return null;
    }
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || parts[2].isEmpty || parts[3].isEmpty) {
      return null;
    }
    return _StoredPinHash(
      iterations: iterations,
      salt: parts[2],
      digest: parts[3],
    );
  }
}
