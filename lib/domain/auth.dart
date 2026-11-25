library;

import 'shared.dart';

export 'shared.dart' show DomainException;

/// E-mail address of a parent or guardian, normalized to lower case.
class Email {
  final String value;
  const Email._(this.value);

  /// Validates and normalizes [raw].
  ///
  /// Throws a [DomainException] when the value is empty or is not a valid
  /// e-mail address.
  factory Email(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) {
      throw const DomainException('Ingresa tu correo electrónico.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      throw const DomainException('Ingresa un correo electrónico válido.');
    }
    return Email._(v);
  }

  @override
  bool operator ==(Object other) => other is Email && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Rules that a new password must satisfy.
///
/// Besides length and character classes, it rejects repeated characters,
/// sequences such as 1234 or qwer, and common passwords, because those are the
/// first values tried when guessing an account.
abstract final class PasswordPolicy {
  static const minLength = 8;

  static final rules = <(String, bool Function(String))>[
    ('Al menos $minLength caracteres', (p) => p.length >= minLength),
    ('Una letra mayúscula', (p) => p.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]'))),
    ('Una letra minúscula', (p) => p.contains(RegExp(r'[a-záéíóúñ]'))),
    ('Un número', (p) => p.contains(RegExp(r'[0-9]'))),
    ('Sin el mismo carácter 3 veces seguidas',
        (p) => p.isNotEmpty && !p.contains(RegExp(r'(.)\1\1'))),
    ('Sin secuencias como 1234 o abcd',
        (p) => p.isNotEmpty && !_hasSequence(p.toLowerCase())),
    ('Que no sea una contraseña común',
        (p) => p.isNotEmpty && !_isCommon(p.toLowerCase())),
  ];

  static const _keyboardRows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  static const _common = [
    'password',
    'contrasena',
    'contraseña',
    'qwerty',
    'gestuvoz',
    'iloveyou',
    'teamo',
    'welcome',
    'admin',
    'letmein',
  ];

  /// Whether [p] contains four ascending or descending characters, or four
  /// adjacent keys of a keyboard row.
  static bool _hasSequence(String p) {
    const length = 4;
    for (var i = 0; i + length <= p.length; i++) {
      final part = p.substring(i, i + length);
      final codes = part.codeUnits;
      final up = [for (var k = 1; k < length; k++) codes[k] - codes[k - 1]]
          .every((d) => d == 1);
      final down = [for (var k = 1; k < length; k++) codes[k] - codes[k - 1]]
          .every((d) => d == -1);
      if (up || down) return true;
      for (final row in _keyboardRows) {
        if (row.contains(part) ||
            row.split('').reversed.join().contains(part)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isCommon(String p) => _common.any(p.contains);

  /// Evaluates every rule against [password] and returns its label and result,
  /// so the registration screen can show which requirements are still missing.
  static List<(String, bool)> check(String password) =>
      [for (final (label, test) in rules) (label, test(password))];

  /// Whether [password] satisfies every rule.
  static bool isStrong(String password) =>
      rules.every((r) => r.$2(password));
}

/// Raised when a new account tries to sign in before confirming its e-mail.
class EmailNotVerifiedException extends DomainException {
  const EmailNotVerifiedException()
      : super('Confirma tu correo antes de iniciar sesión. Revisa tu bandeja '
            'de entrada y también la carpeta de spam.');
}

/// Salted hash of a secret. The plain value is never stored.
class SecretHash {
  final String hash;
  final String salt;
  const SecretHash({required this.hash, required this.salt});
}

abstract final class AccessState {
  static const active = 'activo';
}

/// Local account of a parent or guardian.
class Account {
  final int? id;
  final Email email;
  final String accessState;
  final SecretHash password;

  const Account({
    this.id,
    required this.email,
    this.accessState = AccessState.active,
    required this.password,
  });

  Account withId(int id) => Account(
      id: id, email: email, accessState: accessState, password: password);
}

/// Local persistence of the accounts that signed in on this device.
abstract interface class AuthRepository {
  Future<Account?> findByEmail(Email email);
  Future<Account?> findById(int id);
  Future<Account> insert(Account account);

  Future<Account?> findByRemoteUid(String uid);

  /// Creates or updates the local account bound to the remote user [uid], so
  /// the data of each guardian stays separated on a shared device.
  Future<Account> linkRemote({
    required String uid,
    required Email email,
    required SecretHash password,
  });
}

/// User returned by the remote authentication provider.
class RemoteUser {
  final String uid;
  final String email;
  final bool emailVerified;
  final DateTime? createdAt;
  const RemoteUser({
    required this.uid,
    required this.email,
    this.emailVerified = true,
    this.createdAt,
  });
}

/// Remote authentication provider (Firebase Authentication in production).
abstract interface class RemoteAuthGateway {
  RemoteUser? get currentUser;
  Future<RemoteUser> register(String email, String password);
  Future<RemoteUser> signIn(String email, String password);
  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  Future<void> sendEmailVerification();

  /// Token that authenticates the guardian against the backend API.
  ///
  /// Set [forceRefresh] when the backend rejected the cached token.
  Future<String?> idToken({bool forceRefresh = false});
}

/// Hashes and verifies secrets without keeping their plain value.
abstract interface class SecretHasher {
  SecretHash hash(String plaintext);
  bool verify(String plaintext, SecretHash against);
}
