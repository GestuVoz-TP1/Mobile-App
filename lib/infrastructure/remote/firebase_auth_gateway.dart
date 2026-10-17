import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/auth.dart';

/// Adaptador de Firebase Authentication (OB2 RT-04, RF-10).
class FirebaseAuthGateway implements RemoteAuthGateway {
  FirebaseAuthGateway([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  RemoteUser _map(User u) => RemoteUser(uid: u.uid, email: u.email ?? '');

  @override
  RemoteUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _map(u);
  }

  @override
  Future<RemoteUser> register(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return _map(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw DomainException(_message(e, registering: true));
    }
  }

  @override
  Future<RemoteUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return _map(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw DomainException(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Por seguridad no se revela si el correo esta registrado.
      if (e.code == 'user-not-found') return;
      throw DomainException(_message(e));
    }
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  static String _message(FirebaseAuthException e, {bool registering = false}) {
    return switch (e.code) {
      'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
      'invalid-email' => 'Ingresa un correo electrónico válido.',
      'weak-password' => 'La contraseña es demasiado débil.',
      'network-request-failed' =>
        'No hay conexión a internet. Conéctate e inténtalo de nuevo.',
      'too-many-requests' =>
        'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      _ => registering
          ? 'No se pudo crear la cuenta. Inténtalo de nuevo.'
          // HU019 criterio 2: mismo mensaje para no revelar si el correo existe.
          : 'No se pudo iniciar sesión. Revisa tu correo y contraseña.',
    };
  }
}
