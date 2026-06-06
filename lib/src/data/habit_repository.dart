import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../core/models.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  throw UnimplementedError('HabitRepository must be provided at app startup.');
});

abstract class HabitRepository {
  Future<AppState> load();
  Future<void> save(AppState state);
}

class HiveHabitRepository implements HabitRepository {
  HiveHabitRepository._(this._box);

  static const _boxName = 'stillpoint_state';
  static const _legacyBoxName = 'mindful_recovery_state';
  static const _stateKey = 'state';
  static const _encryptionKeyName = 'stillpoint_hive_key_v1';
  static const _legacyEncryptionKeyName = 'mindful_recovery_hive_key_v1';

  final Box<dynamic> _box;

  static Future<HiveHabitRepository> open() async {
    const secureStorage = FlutterSecureStorage();
    var encodedKey = await secureStorage.read(key: _encryptionKeyName);
    final legacyEncodedKey = await secureStorage.read(
      key: _legacyEncryptionKeyName,
    );
    var canReadLegacyBox =
        legacyEncodedKey != null && legacyEncodedKey == encodedKey;

    if (encodedKey == null) {
      if (legacyEncodedKey != null) {
        encodedKey = legacyEncodedKey;
        canReadLegacyBox = true;
      } else {
        final key = Hive.generateSecureKey();
        encodedKey = base64UrlEncode(key);
      }
      await secureStorage.write(key: _encryptionKeyName, value: encodedKey);
    }

    final cipher = HiveAesCipher(base64Url.decode(encodedKey));
    final box = await Hive.openBox<dynamic>(_boxName, encryptionCipher: cipher);
    if (canReadLegacyBox) {
      await _migrateLegacyBoxIfNeeded(box, cipher);
    }

    return HiveHabitRepository._(box);
  }

  static Future<void> _migrateLegacyBoxIfNeeded(
    Box<dynamic> box,
    HiveAesCipher cipher,
  ) async {
    if (box.containsKey(_stateKey)) return;

    try {
      if (!await Hive.boxExists(_legacyBoxName)) return;
      final legacyBox = await Hive.openBox<dynamic>(
        _legacyBoxName,
        encryptionCipher: cipher,
      );
      try {
        final legacyState = legacyBox.get(_stateKey);
        if (legacyState != null) {
          await box.put(_stateKey, legacyState);
        }
      } finally {
        await legacyBox.close();
      }
    } on HiveError {
      // Keep startup healthy if an old local box cannot be read.
    }
  }

  @override
  Future<AppState> load() async {
    final raw = _box.get(_stateKey);
    if (raw is Map) {
      return AppState.fromMap(Map<String, dynamic>.from(raw));
    }

    final initial = AppState.initial();
    await save(initial);
    return initial;
  }

  @override
  Future<void> save(AppState state) async {
    await _box.put(_stateKey, state.toMap());
  }
}
