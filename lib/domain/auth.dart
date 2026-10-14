/// -------------------------------------------------------------------------
/// Bounded context: AUTENTICACION (entidad PADRE_TUTOR)
///
/// Acceso del padre o tutor. En esta etapa el acceso es LOCAL: la contrasena
/// se guarda como hash con sal en SQLite. En una etapa posterior lo
/// reemplazara Firebase Authentication (OB2, RT-04).
/// -------------------------------------------------------------------------
library;

import 'shared.dart';

export 'shared.dart' show DomainException;

/// Value object: correo electronico normalizado (PADRE_TUTOR.correo_electronico).
class Email {
  final String value;
  const Email._(this.value);

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

/// Credenciales hasheadas que se persisten (nunca se guarda la contrasena en
/// claro). El hashing concreto vive en infraestructura.
class SecretHash {
  final String hash;
  final String salt;
  const SecretHash({required this.hash, required this.salt});
}

/// PADRE_TUTOR.estado_acceso
abstract final class AccessState {
  static const active = 'activo';
}

/// Aggregate root del contexto de autenticacion (PADRE_TUTOR).
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

/// Puerto (interface) hacia la persistencia de PADRE_TUTOR.
abstract interface class AuthRepository {
  Future<Account?> findByEmail(Email email);
  Future<Account?> findById(int id);
  Future<Account> insert(Account account);
}

/// Servicio de infraestructura para derivar y verificar hashes.
abstract interface class SecretHasher {
  SecretHash hash(String plaintext);
  bool verify(String plaintext, SecretHash against);
}
