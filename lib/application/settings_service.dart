import '../domain/settings.dart';

/// Configuracion de voz por perfil.
class SettingsService {
  SettingsService(this._repo);
  final VoiceConfigurationRepository _repo;

  Future<VoiceConfiguration> voiceFor(int profileId) =>
      _repo.forProfile(profileId);

  /// Valida los valores permitidos antes de guardar.
  Future<void> saveVoice(VoiceConfiguration c) => _repo.save(c.validated());
}
