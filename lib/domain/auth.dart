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

  /// Tutor local vinculado al usuario de Firebase Authentication.
  Future<Account?> findByRemoteUid(String uid);

  /// Crea o actualiza el tutor local que corresponde a un usuario de
  /// Firebase. Guarda el hash de la contrasena para poder verificarla sin
  /// conexion (salir del modo nino).
  Future<Account> linkRemote({
    required String uid,
    required Email email,
    required SecretHash password,
  });
}

/// Usuario autenticado en el servicio remoto (Firebase Authentication).
class RemoteUser {
  final String uid;
  final String email;
  const RemoteUser({required this.uid, required this.email});
}

/// Puerto hacia el servicio de autenticacion remoto (OB2 RT-04).
abstract interface class RemoteAuthGateway {
  /// Usuario con sesion guardada en el dispositivo (funciona sin conexion).
  RemoteUser? get currentUser;
  Future<RemoteUser> register(String email, String password);
  Future<RemoteUser> signIn(String email, String password);
  Future<void> signOut();

  /// HU020: envia el correo para restablecer la contrasena.
  Future<void> sendPasswordReset(String email);

  /// Token para llamar al backend; null si no hay sesion.
  Future<String?> idToken({bool forceRefresh = false});
}

/// Servicio de infraestructura para derivar y verificar hashes.
abstract interface class SecretHasher {
  SecretHash hash(String plaintext);
  bool verify(String plaintext, SecretHash against);
}
