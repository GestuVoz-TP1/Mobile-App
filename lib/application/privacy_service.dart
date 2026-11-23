import '../domain/consent.dart';

/// Use cases of the consent given by the guardian.
class PrivacyService {
  PrivacyService(this._consents);
  final ConsentRepository _consents;

  Future<Consent?> forProfile(int profileId) => _consents.forProfile(profileId);

  Future<Consent> decide(int profileId, {required bool granted}) =>
      _consents.save(Consent(
        profileId: profileId,
        state: granted ? ConsentState.granted : ConsentState.notGranted,
        registeredAt: DateTime.now(),
      ));

  /// Withdraws the consent. From then on no new interaction is registered and
  /// the camera is not used for this profile.
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

  /// Whether the data of [profileId] can be processed.
  Future<bool> allowsProcessing(int profileId) async =>
      (await _consents.forProfile(profileId))?.allowsProcessing ?? false;
}
