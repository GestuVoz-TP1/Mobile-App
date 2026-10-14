import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../domain/auth.dart';

/// Implementacion de [SecretHasher] con SHA-256 + salt aleatorio.
///
/// Suficiente para el prototipo local (no viaja por red). En produccion se
/// usaria Argon2/bcrypt/scrypt.
class Sha256SecretHasher implements SecretHasher {
  final Random _rnd = Random.secure();

  @override
  SecretHash hash(String plaintext) {
    final salt = _salt();
    return SecretHash(hash: _digest(plaintext, salt), salt: salt);
  }

  @override
  bool verify(String plaintext, SecretHash against) =>
      _digest(plaintext, against.salt) == against.hash;

  String _salt() {
    final bytes = List<int>.generate(16, (_) => _rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _digest(String plaintext, String salt) =>
      sha256.convert(utf8.encode('$salt::$plaintext')).toString();
}
