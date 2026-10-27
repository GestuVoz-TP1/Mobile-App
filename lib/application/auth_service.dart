import '../domain/auth.dart';

/// Datos del registro (HU018): solo correo y contrasena.
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

/// Servicio de aplicacion del contexto de autenticacion.
///
/// Con [RemoteAuthGateway] (Firebase Authentication) el registro, el inicio
/// de sesion y la recuperacion de contrasena se hacen en Firebase; el tutor
/// local se vincula a su UID y guarda el hash de la contrasena para
/// verificarla sin conexion (salir del modo nino). Sin gateway, el acceso es
/// solo local.
class AuthService {
  AuthService(this._accounts, this._hasher, [this._remote]);
  final AuthRepository _accounts;
  final SecretHasher _hasher;
  final RemoteAuthGateway? _remote;

  /// Longitud minima de contrasena (OB2, mockup "Crear cuenta").
  static const minPasswordLength = 8;

  static const _invalidLogin = DomainException(
      'No se pudo iniciar sesión. Revisa tu correo y contraseña.');

  bool get usesRemoteAuth => _remote != null;

  Email _validateRegistration(RegistrationForm f) {
    final email = Email(f.email); // valida formato (HU018, criterio 2)
    if (f.password.isEmpty) {
      throw const DomainException('Ingresa una contraseña.');
    }
    if (f.password.length < minPasswordLength) {
      throw const DomainException(
          'La contraseña debe tener al menos $minPasswordLength caracteres.');
    }
    if (f.password != f.passwordConfirm) {
      throw const DomainException('Las contraseñas no coinciden.');
    }
    return email;
  }

  Future<Account> register(RegistrationForm f) async {
    final email = _validateRegistration(f);
    final remote = _remote;
    if (remote != null) {
      final user = await remote.register(email.value, f.password);
      return _accounts.linkRemote(
          uid: user.uid, email: email, password: _hasher.hash(f.password));
    }
    if (await _accounts.findByEmail(email) != null) {
      throw const DomainException('Ya existe una cuenta con ese correo.');
    }
    return _accounts.insert(Account(
      email: email,
      password: _hasher.hash(f.password),
    ));
  }

  /// HU019. Ante cualquier error devuelve el mismo mensaje para no revelar
  /// si el correo existe (criterio 2: "mantiene protegida la informacion").
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

  /// Sesion guardada de Firebase (funciona sin conexion): permite que el
  /// nino siga usando la app aunque se reinicie sin internet.
  Future<Account?> restoreSession() async {
    final user = _remote?.currentUser;
    if (user == null) return null;
    return _accounts.findByRemoteUid(user.uid);
  }

  Future<void> logout() async => _remote?.signOut();

  /// HU020: envia el correo de restablecimiento (requiere Firebase).
  Future<void> sendPasswordReset(String email) async {
    final parsed = Email(email); // criterio 2: valida el formato
    final remote = _remote;
    if (remote == null) {
      throw const DomainException(
          'La recuperación de contraseña requiere el servicio en línea.');
    }
    await remote.sendPasswordReset(parsed.value);
  }

  /// Salir del modo nino pide la contrasena del tutor (verificacion local,
  /// sin conexion).
  Future<bool> verifyPassword(int tutorId, String password) async {
    final acc = await _accounts.findById(tutorId);
    return acc != null && _hasher.verify(password, acc.password);
  }
}
