import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/settings.dart';

/// Voz disponible en el motor TTS del dispositivo.
class TtsVoice {
  final String name;
  final String locale;
  const TtsVoice(this.name, this.locale);
}

/// Sintesis de voz (soporte auditivo de los pictogramas). Degrada de forma
/// segura si el dispositivo no tiene motor TTS en espanol.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool available = true;

  Future<void> init() async {
    try {
      await _tts.setLanguage(VoiceLimits.defaultLanguage);
      await _tts.setSpeechRate(VoiceLimits.defaultRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (e) {
      available = false;
      debugPrint('TTS no disponible: $e');
    }
  }

  /// Aplica la CONFIGURACION_VOZ del perfil activo.
  Future<void> configure(VoiceConfiguration c) async {
    if (!_ready) return;
    try {
      await _tts.setLanguage(c.language);
      if (c.voiceType != null) {
        await _tts.setVoice({'name': c.voiceType!, 'locale': c.language});
      }
      await _tts.setSpeechRate(c.rate);
      await _tts.setVolume(c.volume);
    } catch (e) {
      debugPrint('TTS configure error: $e');
    }
  }

  /// Voces en espanol del dispositivo (selector del mockup 11).
  Future<List<TtsVoice>> spanishVoices() async {
    if (!_ready) return const [];
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      final voices = <TtsVoice>[];
      for (final v in raw) {
        if (v is Map) {
          final name = v['name']?.toString();
          final locale = v['locale']?.toString() ?? '';
          if (name != null && locale.toLowerCase().startsWith('es')) {
            voices.add(TtsVoice(name, locale));
          }
        }
      }
      voices.sort((a, b) => a.locale.compareTo(b.locale));
      return voices;
    } catch (_) {
      return const [];
    }
  }

  /// Reproduce [text]. Devuelve false si no se pudo reproducir (HU009,
  /// criterio 2: la app debe informarlo).
  Future<bool> speak(String text) async {
    if (!_ready || text.trim().isEmpty) return false;
    try {
      await _tts.stop();
      final r = await _tts.speak(text);
      return r == 1 || r == true;
    } catch (e) {
      debugPrint('TTS speak error: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (_ready) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }
}
