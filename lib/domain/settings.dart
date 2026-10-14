/// -------------------------------------------------------------------------
/// Bounded context: CONFIGURACION DE VOZ (CONFIGURACION_VOZ)
///
/// Preferencias de reproduccion de mensajes de cada perfil (OB2: idioma, tipo
/// de voz, velocidad y volumen; HU017). PERFIL_NINO 1:1 CONFIGURACION_VOZ.
/// -------------------------------------------------------------------------
library;

import 'shared.dart';

export 'shared.dart' show DomainException;

/// Valores permitidos (HU017, criterio 2).
abstract final class VoiceLimits {
  static const minRate = 0.2;
  static const maxRate = 0.8;
  static const defaultRate = 0.45;
  static const minVolume = 0.1;
  static const maxVolume = 1.0;

  /// Solo espanol (Project Charter: sin soporte multi-idioma).
  static const defaultLanguage = 'es-ES';
}

class VoiceConfiguration {
  final int? id;
  final int profileId;
  final String language;

  /// Nombre de la voz del motor TTS; null = voz por defecto del dispositivo.
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

  /// Valida los valores antes de guardar (HU017, criterio 2).
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
