import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/settings.dart';

class TtsVoice {
  final String name;
  final String locale;
  final bool needsNetwork;
  const TtsVoice(this.name, this.locale, {this.needsNetwork = false});

  VoiceGender? get gender => voiceGenderOf(name);
}

class VoiceChoice {
  final TtsVoice? voice;
  final double pitch;
  const VoiceChoice(this.voice, this.pitch);

  bool get usesPitchOnly => voice == null && pitch != 1.0;
}

const _googleVoiceGenders = {
  'eea': VoiceGender.female,
  'eec': VoiceGender.female,
  'eed': VoiceGender.male,
  'eef': VoiceGender.male,
  'esc': VoiceGender.female,
  'esd': VoiceGender.male,
  'esf': VoiceGender.female,
  'sfb': VoiceGender.female,
};

VoiceGender? voiceGenderOf(String name) {
  final n = name.toLowerCase();
  if (RegExp(r'(^|[^a-z])(female|femenin|mujer)').hasMatch(n)) {
    return VoiceGender.female;
  }
  if (RegExp(r'(^|[^a-z])(male|masculin|hombre)').hasMatch(n)) {
    return VoiceGender.male;
  }
  final google = RegExp(r'-x-([a-z]{3})(-|$)').firstMatch(n);
  return google == null ? null : _googleVoiceGenders[google.group(1)];
}

VoiceChoice chooseVoice(
    List<TtsVoice> voices, VoiceGender? gender, String language) {
  if (gender == null) return const VoiceChoice(null, 1.0);
  final lang = language.toLowerCase();
  int region(TtsVoice v) {
    final l = v.locale.toLowerCase();
    if (l.startsWith('es-es') || l.startsWith('es_es')) return 0;
    return l == lang ? 1 : 2;
  }

  int score(TtsVoice v) => (v.needsNetwork ? 3 : 0) + region(v);
  final matching = voices.where((v) => v.gender == gender).toList()
    ..sort((a, b) => score(a).compareTo(score(b)));
  if (matching.isNotEmpty) return VoiceChoice(matching.first, 1.0);
  return VoiceChoice(null, gender == VoiceGender.male ? 0.8 : 1.1);
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool available = true;
  List<TtsVoice>? _voices;
  String _language = VoiceLimits.defaultLanguage;

  Future<String> _pickLanguage() async {
    for (final l in VoiceLimits.preferredLanguages) {
      try {
        final ok = await _tts.isLanguageAvailable(l);
        if (ok == true || ok == 1) return l;
      } catch (_) {}
    }
    return VoiceLimits.defaultLanguage;
  }

  Future<void> init() async {
    try {
      _language = await _pickLanguage();
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(VoiceLimits.defaultRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (e) {
      available = false;
      debugPrint('TTS no disponible: $e');
    }
  }

  Future<void> configure(VoiceConfiguration c, {String? childGender}) async {
    if (!_ready) return;
    try {
      await _tts.setLanguage(_language);
      final choice = chooseVoice(
          await spanishVoices(), c.genderFor(childGender), _language);
      final voice = choice.voice;
      if (voice != null) {
        await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      } else {
        await _resetVoice();
      }
      await _tts.setPitch(choice.pitch);
      await _tts.setSpeechRate(c.rate);
      await _tts.setVolume(c.volume);
    } catch (e) {
      debugPrint('TTS configure error: $e');
    }
  }

  Future<void> _resetVoice() async {
    try {
      await _tts.clearVoice();
    } catch (_) {}
  }

  Future<List<TtsVoice>> spanishVoices() async {
    if (!_ready) return const [];
    final cached = _voices;
    if (cached != null) return cached;
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      final voices = <TtsVoice>[];
      for (final v in raw) {
        if (v is Map) {
          final name = v['name']?.toString();
          final locale = v['locale']?.toString() ?? '';
          final features = v['features']?.toString() ?? '';
          if (name != null &&
              locale.toLowerCase().startsWith('es') &&
              !features.contains('notInstalled')) {
            voices.add(TtsVoice(name, locale,
                needsNetwork: v['network_required']?.toString() == '1'));
          }
        }
      }
      voices.sort((a, b) => a.locale.compareTo(b.locale));
      return _voices = voices;
    } catch (_) {
      return const [];
    }
  }

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
