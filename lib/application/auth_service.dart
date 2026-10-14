import '../domain/auth.dart';

/// Datos del registro (HU018). D2: solo correo y contrasena.
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

/// Servicio de aplicacion del contexto de autenticacion (acceso local).
class AuthService {
  AuthService(this._accounts, this._hasher);
  final AuthRepository _accounts;
  final SecretHasher _hasher;

  /// Longitud minima de contrasena (OB2, mockup "Crear cuenta").
  static const minPasswordLength = 8;

  Future<Account> register(RegistrationForm f) async {
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
    const invalid = DomainException(
        'No se pudo iniciar sesión. Revisa tu correo y contraseña.');
    final Email parsed;
    try {
      parsed = Email(email);
    } on DomainException {
      throw invalid;
    }
    final acc = await _accounts.findByEmail(parsed);
    if (acc == null ||
        acc.accessState != AccessState.active ||
        !_hasher.verify(password, acc.password)) {
      throw invalid;
    }
    return acc;
  }

  /// D1: salir del modo nino pide la contrasena del tutor.
  Future<bool> verifyPassword(int tutorId, String password) async {
    final acc = await _accounts.findById(tutorId);
    return acc != null && _hasher.verify(password, acc.password);
  }
}
