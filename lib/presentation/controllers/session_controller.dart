import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/auth_service.dart';
import '../../application/privacy_service.dart';
import '../../application/profile_service.dart';
import '../../application/settings_service.dart';
import '../../domain/auth.dart';
import '../../domain/child.dart';
import '../../domain/consent.dart';
import '../../domain/settings.dart';
import '../../infrastructure/tts/tts_service.dart';

/// Experiencia activa tras iniciar sesion (OB2, Fig. 8: panel del nino o
/// panel del padre/tutor).
enum AppMode { none, child, caregiver }

/// Estado de sesion global: tutor autenticado, perfiles, perfil activo, modo,
/// configuracion de voz y consentimiento del perfil activo.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService auth,
    required ProfileService profiles,
    required PrivacyService privacy,
    required SettingsService settings,
    required TtsService tts,
  })  : _auth = auth,
        _profiles = profiles,
        _privacy = privacy,
        _settings = settings,
        _tts = tts;

  final AuthService _auth;
  final ProfileService _profiles;
  final PrivacyService _privacy;
  final SettingsService _settings;
  final TtsService _tts;

  bool _ready = false;
  bool get ready => _ready;

  Account? _account;
  Account? get account => _account;
  bool get isLoggedIn => _account != null;

  List<ChildProfile> _profileList = const [];
  List<ChildProfile> get profiles => _profileList;

  ChildProfile? _active;
  ChildProfile? get activeProfile => _active;

  VoiceConfiguration? _voice;
  VoiceConfiguration? get voice => _voice;

  Consent? _consent;
  Consent? get consent => _consent;

  /// Con consentimiento vigente se registran interacciones y se habilita
  /// la camara de gestos.
  bool get consentAllowsProcessing => _consent?.allowsProcessing ?? false;

  AppMode _mode = AppMode.none;
  AppMode get mode => _mode;

  bool get ttsAvailable => _tts.available;
  bool get highContrast =>
      _active?.preferences.highContrast ?? false;

  /// Se ejecuta tras iniciar sesion (descarga de datos del backend). Un
  /// error aqui no impide entrar: los datos locales siguen disponibles.
  Future<void> Function(Account account)? afterSignIn;

  /// Se ejecuta al cerrar sesion.
  Future<void> Function()? afterSignOut;

  Future<void> bootstrap() async {
    await _tts.init();
    // Sesion guardada de Firebase: no requiere conexion.
    final restored = await _auth.restoreSession();
    if (restored != null) {
      _account = restored;
      await _loadProfiles();
      _runAfterSignIn(restored, wait: false);
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _runAfterSignIn(Account account, {required bool wait}) async {
    final hook = afterSignIn;
    if (hook == null) return;
    Future<void> run() async {
      try {
        await hook(account);
        if (_account?.id == account.id) {
          await _loadProfiles();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Sincronizacion inicial no completada: $e');
      }
    }

    wait ? await run() : unawaited(run());
  }

  // --- Acceso (E4) -------------------------------------------------------

  /// HU018: crea la cuenta e inicia la sesion para continuar la configuracion.
  Future<void> register(RegistrationForm form) async {
    _account = await _auth.register(form);
    await _loadProfiles();
    notifyListeners();
    await _runAfterSignIn(_account!, wait: true);
  }

  /// HU019. Recupera del backend los perfiles y la configuracion del tutor.
  Future<void> login(String email, String password) async {
    final account = await _auth.login(email, password);
    await _runAfterSignIn(account, wait: true);
    _account = account;
    await _loadProfiles();
    notifyListeners();
  }

  /// HU020.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  bool get usesRemoteAuth => _auth.usesRemoteAuth;

  /// HU026: termina la sesion y vuelve a la pantalla de acceso.
  Future<void> logout() async {
    await _tts.stop();
    await _auth.logout();
    await afterSignOut?.call();
    _account = null;
    _profileList = const [];
    _active = null;
    _voice = null;
    _consent = null;
    _mode = AppMode.none;
    notifyListeners();
  }

  // --- Perfiles (HU021-HU025) ----------------------------------------------

  Future<void> _loadProfiles() async {
    final acc = _account;
    if (acc == null) return;
    _profileList = await _profiles.forTutor(acc.id!);
    final keep = _active == null
        ? null
        : _profileList.where((p) => p.id == _active!.id).firstOrNull;
    if (keep != null) {
      await _activate(keep);
    } else if (_profileList.length == 1) {
      // Con un unico perfil se selecciona directamente.
      await _activate(_profileList.first);
    } else {
      _active = null;
      _voice = null;
      _consent = null;
    }
  }

  Future<void> _activate(ChildProfile p) async {
    _active = p;
    _voice = await _settings.voiceFor(p.id!);
    _consent = await _privacy.forProfile(p.id!);
    await _tts.configure(_voice!);
  }

  /// HU023 / HU024: carga unicamente los recursos del perfil elegido.
  Future<void> selectProfile(ChildProfile p) async {
    await _activate(p);
    _mode = AppMode.none;
    notifyListeners();
  }

  /// HU021. El nuevo perfil queda activo para registrar su consentimiento.
  Future<ChildProfile> createProfile(ProfileForm form) async {
    final created = await _profiles.create(_account!.id!, form);
    _profileList = await _profiles.forTutor(_account!.id!);
    await _activate(created);
    notifyListeners();
    return created;
  }

  /// HU022.
  Future<void> updateProfile(ChildProfile current, ProfileForm form) async {
    final updated = await _profiles.update(current, form);
    _profileList = await _profiles.forTutor(_account!.id!);
    if (_active?.id == updated.id) _active = updated;
    notifyListeners();
  }

  /// HU004, HU016, RF-15 y alto contraste.
  Future<void> savePreferences(CommunicationPreferences prefs) async {
    final p = _active;
    if (p == null) return;
    _active = await _profiles.savePreferences(p, prefs);
    _profileList = [
      for (final x in _profileList) x.id == p.id ? _active! : x,
    ];
    notifyListeners();
  }

  /// HU025.
  Future<void> deleteProfile(ChildProfile p) async {
    await _profiles.delete(p.id!);
    if (_active?.id == p.id) {
      _active = null;
      _voice = null;
      _consent = null;
    }
    await _loadProfiles();
    _mode = AppMode.none;
    notifyListeners();
  }

  // --- Voz (HU017) -----------------------------------------------------------

  Future<void> saveVoice(VoiceConfiguration v) async {
    await _settings.saveVoice(v);
    _voice = v;
    await _tts.configure(v);
    notifyListeners();
  }

  /// "Probar voz" (mockup 11) con valores aun no guardados.
  Future<bool> previewVoice(VoiceConfiguration v, String text) async {
    await _tts.configure(v);
    final ok = await _tts.speak(text);
    return ok;
  }

  /// Restaura la configuracion guardada tras una vista previa sin guardar.
  Future<void> restoreVoice() async {
    if (_voice != null) await _tts.configure(_voice!);
  }

  Future<List<TtsVoice>> availableVoices() => _tts.spanishVoices();

  // --- Consentimiento (HU027, HU028) ----------------------------------------

  Future<void> decideConsent({required bool granted}) async {
    final p = _active;
    if (p == null) return;
    _consent = await _privacy.decide(p.id!, granted: granted);
    notifyListeners();
  }

  Future<void> withdrawConsent() async {
    final p = _active;
    if (p == null) return;
    _consent = await _privacy.withdraw(p.id!);
    notifyListeners();
  }

  Future<Consent?> reloadConsent() async {
    final p = _active;
    if (p == null) return null;
    _consent = await _privacy.forProfile(p.id!);
    notifyListeners();
    return _consent;
  }

  // --- Modo (OB2, Fig. 8) ------------------------------------------------------

  void enterChildMode() {
    if (_active == null) return;
    _mode = AppMode.child;
    notifyListeners();
  }

  void enterCaregiverMode() {
    _mode = AppMode.caregiver;
    notifyListeners();
  }

  void backToModeSelection() {
    _mode = AppMode.none;
    notifyListeners();
  }

  /// Salir del modo nino pide la contrasena del tutor (sin PIN).
  /// Solo verifica; el cambio de pantalla lo hace [leaveChildMode] una vez
  /// cerrado el dialogo.
  Future<bool> verifyTutorPassword(String password) async {
    final acc = _account;
    if (acc == null) return false;
    return _auth.verifyPassword(acc.id!, password);
  }

  Future<void> leaveChildMode() async {
    await _tts.stop();
    _mode = AppMode.none;
    notifyListeners();
  }
}
