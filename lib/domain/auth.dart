library;

import 'shared.dart';

export 'shared.dart' show DomainException;

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

class SecretHash {
  final String hash;
  final String salt;
  const SecretHash({required this.hash, required this.salt});
}

abstract final class AccessState {
  static const active = 'activo';
}

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

abstract interface class AuthRepository {
  Future<Account?> findByEmail(Email email);
  Future<Account?> findById(int id);
  Future<Account> insert(Account account);

  Future<Account?> findByRemoteUid(String uid);

  Future<Account> linkRemote({
    required String uid,
    required Email email,
    required SecretHash password,
  });
}

class RemoteUser {
  final String uid;
  final String email;
  const RemoteUser({required this.uid, required this.email});
}

abstract interface class RemoteAuthGateway {
  RemoteUser? get currentUser;
  Future<RemoteUser> register(String email, String password);
  Future<RemoteUser> signIn(String email, String password);
  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  Future<String?> idToken({bool forceRefresh = false});
}

abstract interface class SecretHasher {
  SecretHash hash(String plaintext);
  bool verify(String plaintext, SecretHash against);
}
