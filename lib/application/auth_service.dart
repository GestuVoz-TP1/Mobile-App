import '../domain/auth.dart';

class RegistrationForm {
  final String email;
  final String password;
  final String passwordConfirm;

  const RegistrationForm({
    required this.email,
    required this.password,
    required this.passwordConfirm,
  });
}

class AuthService {
  AuthService(this._accounts, this._hasher, [this._remote]);
  final AuthRepository _accounts;
  final SecretHasher _hasher;
  final RemoteAuthGateway? _remote;

  static final verificationRequiredSince = DateTime.utc(2026, 11, 17);

  static const _invalidLogin = DomainException(
      'No se pudo iniciar sesión. Revisa tu correo y contraseña.');

  bool get usesRemoteAuth => _remote != null;

  Email _validateRegistration(RegistrationForm f) {
    final email = Email(f.email);
    if (f.password.isEmpty) {
      throw const DomainException('Ingresa una contraseña.');
    }
    if (!PasswordPolicy.isStrong(f.password)) {
      throw const DomainException(
          'Elige una contraseña más segura: revisa los requisitos que '
          'aparecen debajo del campo.');
    }
    if (f.password != f.passwordConfirm) {
      throw const DomainException('Las contraseñas no coinciden.');
    }
    return email;
  }

  bool mustVerify(RemoteUser user) {
    if (user.emailVerified) return false;
    final created = user.createdAt;
    return created == null || !created.isBefore(verificationRequiredSince);
  }

  bool get currentEmailUnverified =>
      _remote?.currentUser?.emailVerified == false;

  Future<Account?> register(RegistrationForm f) async {
    final email = _validateRegistration(f);
    final remote = _remote;
    if (remote != null) {
      await remote.register(email.value, f.password);
      try {
        await remote.sendEmailVerification();
      } on DomainException {
        return null;
      } finally {
        await remote.signOut();
      }
      return null;
    }
    if (await _accounts.findByEmail(email) != null) {
      throw const DomainException('Ya existe una cuenta con ese correo.');
    }
    return _accounts.insert(Account(
      email: email,
      password: _hasher.hash(f.password),
    ));
  }

  Future<Account> login(String email, String password) async {
    final Email parsed;
    try {
      parsed = Email(email);
    } on DomainException {
      throw _invalidLogin;
    }
    final remote = _remote;
    if (remote != null) {
      final user = await remote.signIn(parsed.value, password);
      if (mustVerify(user)) {
        await remote.signOut();
        throw const EmailNotVerifiedException();
      }
      return _accounts.linkRemote(
          uid: user.uid, email: parsed, password: _hasher.hash(password));
    }
    final acc = await _accounts.findByEmail(parsed);
    if (acc == null ||
        acc.accessState != AccessState.active ||
        !_hasher.verify(password, acc.password)) {
      throw _invalidLogin;
    }
    return acc;
  }

  Future<Account?> restoreSession() async {
    final remote = _remote;
    final user = remote?.currentUser;
    if (remote == null || user == null) return null;
    if (mustVerify(user)) {
      await remote.signOut();
      return null;
    }
    return _accounts.findByRemoteUid(user.uid);
  }

  Future<void> resendVerification(String email, String password) async {
    final parsed = Email(email);
    final remote = _remote;
    if (remote == null) return;
    await remote.signIn(parsed.value, password);
    try {
      await remote.sendEmailVerification();
    } finally {
      await remote.signOut();
    }
  }

  Future<void> sendVerificationToCurrentUser() async =>
      _remote?.sendEmailVerification();

  Future<void> logout() async => _remote?.signOut();

  Future<void> sendPasswordReset(String email) async {
    final parsed = Email(email);
    final remote = _remote;
    if (remote == null) {
      throw const DomainException(
          'La recuperación de contraseña requiere el servicio en línea.');
    }
    await remote.sendPasswordReset(parsed.value);
  }

  Future<bool> verifyPassword(int tutorId, String password) async {
    final acc = await _accounts.findById(tutorId);
    return acc != null && _hasher.verify(password, acc.password);
  }
}
