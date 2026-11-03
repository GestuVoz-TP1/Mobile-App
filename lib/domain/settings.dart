library;

import 'shared.dart';

export 'shared.dart' show DomainException;

abstract final class VoiceLimits {
  static const minRate = 0.2;
  static const maxRate = 0.8;
  static const defaultRate = 0.45;
  static const minVolume = 0.1;
  static const maxVolume = 1.0;

  static const defaultLanguage = 'es-ES';
}

class VoiceConfiguration {
  final int? id;
  final int profileId;
  final String language;

  final String? voiceType;
  final double rate;
  final double volume;
  final bool voiceEnabled;

  const VoiceConfiguration({
    this.id,
    required this.profileId,
    this.language = VoiceLimits.defaultLanguage,
    this.voiceType,
    this.rate = VoiceLimits.defaultRate,
    this.volume = 1.0,
    this.voiceEnabled = true,
  });

  VoiceConfiguration validated() {
    if (rate < VoiceLimits.minRate || rate > VoiceLimits.maxRate) {
      throw const DomainException(
          'Selecciona una velocidad dentro de las opciones disponibles.');
    }
    if (volume < VoiceLimits.minVolume || volume > VoiceLimits.maxVolume) {
      throw const DomainException(
          'Selecciona un volumen dentro de las opciones disponibles.');
    }
    if (!language.toLowerCase().startsWith('es')) {
      throw const DomainException('La voz debe estar en español.');
    }
    return this;
  }

  VoiceConfiguration copyWith({
    String? language,
    String? voiceType,
    bool clearVoiceType = false,
    double? rate,
    double? volume,
    bool? voiceEnabled,
  }) =>
      VoiceConfiguration(
        id: id,
        profileId: profileId,
        language: language ?? this.language,
        voiceType: clearVoiceType ? null : (voiceType ?? this.voiceType),
        rate: rate ?? this.rate,
        volume: volume ?? this.volume,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      );
}

abstract interface class VoiceConfigurationRepository {
  Future<VoiceConfiguration> forProfile(int profileId);
  Future<void> save(VoiceConfiguration configuration);
}
