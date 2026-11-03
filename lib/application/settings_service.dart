import '../domain/settings.dart';

class SettingsService {
  SettingsService(this._repo);
  final VoiceConfigurationRepository _repo;

  Future<VoiceConfiguration> voiceFor(int profileId) =>
      _repo.forProfile(profileId);

  Future<void> saveVoice(VoiceConfiguration c) => _repo.save(c.validated());
}
