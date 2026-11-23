import '../domain/settings.dart';

/// Use cases of the voice settings of each profile.
class SettingsService {
  SettingsService(this._repo);
  final VoiceConfigurationRepository _repo;

  Future<VoiceConfiguration> voiceFor(int profileId) =>
      _repo.forProfile(profileId);

  Future<void> saveVoice(VoiceConfiguration c) => _repo.save(c.validated());
}
