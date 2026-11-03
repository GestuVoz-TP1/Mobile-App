import '../domain/consent.dart';

/// Consentimiento por perfil.
class PrivacyService {
  PrivacyService(this._consents);
  final ConsentRepository _consents;

  Future<Consent?> forProfile(int profileId) => _consents.forProfile(profileId);

  /// Registra la decision del tutor. Si no otorga el consentimiento, queda
  /// registrado como "no otorgado".
  Future<Consent> decide(int profileId, {required bool granted}) =>
      _consents.save(Consent(
        profileId: profileId,
        state: granted ? ConsentState.granted : ConsentState.notGranted,
        registeredAt: DateTime.now(),
      ));

  /// Registra el retiro. No borra datos existentes.
  Future<Consent> withdraw(int profileId) async {
    final current = await _consents.forProfile(profileId);
    if (current == null || current.state != ConsentState.granted) {
      throw StateError('No existe un consentimiento vigente.');
    }
    return _consents.save(Consent(
      profileId: profileId,
      state: ConsentState.withdrawn,
      registeredAt: current.registeredAt,
      withdrawnAt: DateTime.now(),
    ));
  }

  /// Con consentimiento vigente se registran interacciones y se habilita
  /// la camara de gestos.
  Future<bool> allowsProcessing(int profileId) async =>
      (await _consents.forProfile(profileId))?.allowsProcessing ?? false;
}
