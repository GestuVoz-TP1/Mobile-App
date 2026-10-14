import '../domain/settings.dart';

/// Servicio de aplicacion: configuracion de voz por perfil (HU017).
class SettingsService {
  SettingsService(this._repo);
  final VoiceConfigurationRepository _repo;

  Future<VoiceConfiguration> voiceFor(int profileId) =>
      _repo.forProfile(profileId);

  /// Valida los valores permitidos antes de guardar (HU017, criterio 2).
  Future<void> saveVoice(VoiceConfiguration c) => _repo.save(c.validated());
}
