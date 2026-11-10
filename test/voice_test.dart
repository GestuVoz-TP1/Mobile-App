import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/domain/settings.dart';
import 'package:gestuvoz/infrastructure/tts/tts_service.dart';

void main() {
  test('La voz automática sigue el género del perfil del niño', () {
    const auto = VoiceConfiguration(profileId: 1);
    expect(auto.isAutomatic, isTrue);
    expect(auto.genderFor('Femenino'), VoiceGender.female);
    expect(auto.genderFor('Masculino'), VoiceGender.male);
    expect(auto.genderFor('Prefiero no indicar'), isNull);
    expect(auto.genderFor(null), isNull);
    const explicitAuto =
        VoiceConfiguration(profileId: 1, voiceType: VoiceTypes.automatic);
    expect(explicitAuto.genderFor('Masculino'), VoiceGender.male);
  });

  test('La voz elegida por el tutor tiene prioridad sobre el perfil', () {
    const female =
        VoiceConfiguration(profileId: 1, voiceType: VoiceTypes.female);
    const male = VoiceConfiguration(profileId: 1, voiceType: VoiceTypes.male);
    expect(female.isAutomatic, isFalse);
    expect(female.genderFor('Masculino'), VoiceGender.female);
    expect(male.genderFor('Femenino'), VoiceGender.male);
    expect(male.genderFor(null), VoiceGender.male);
  });

  test('Reconoce el género de las voces por su nombre', () {
    expect(voiceGenderOf('es-es-x-eed-local'), VoiceGender.male);
    expect(voiceGenderOf('es-us-x-esc-network'), VoiceGender.female);
    expect(voiceGenderOf('Spanish Female'), VoiceGender.female);
    expect(voiceGenderOf('voz-masculina'), VoiceGender.male);
    expect(voiceGenderOf('SMTl02'), isNull);
  });

  test('Elige una voz del género pedido, primero sin internet y del mismo idioma',
      () {
    const voices = [
      TtsVoice('es-us-x-esd-network', 'es-US', needsNetwork: true),
      TtsVoice('es-us-x-esd-local', 'es-US'),
      TtsVoice('es-es-x-eed-network', 'es-ES', needsNetwork: true),
      TtsVoice('es-es-x-eea-local', 'es-ES'),
    ];
    expect(chooseVoice(voices, VoiceGender.male, 'es-ES').voice?.name,
        'es-us-x-esd-local');
    expect(chooseVoice(voices.sublist(2), VoiceGender.male, 'es-ES').voice?.name,
        'es-es-x-eed-network');
    expect(chooseVoice(voices, VoiceGender.female, 'es-ES').voice?.name,
        'es-es-x-eea-local');
    expect(chooseVoice(voices.sublist(0, 2), VoiceGender.male, 'es-ES')
        .voice
        ?.name, 'es-us-x-esd-local');
    final none = chooseVoice(voices, null, 'es-ES');
    expect(none.voice, isNull);
    expect(none.pitch, 1.0);
  });

  test('Prefiere una voz latinoamericana antes que una de España', () {
    const voices = [
      TtsVoice('es-es-x-eea-local', 'es-ES'),
      TtsVoice('es-mx-x-female-local', 'es-MX'),
      TtsVoice('es-us-x-esc-network', 'es-US', needsNetwork: true),
    ];
    expect(VoiceLimits.defaultLanguage, 'es-US');
    expect(chooseVoice(voices, VoiceGender.female, 'es-US').voice?.name,
        'es-mx-x-female-local');
    expect(chooseVoice(voices.sublist(0, 1), VoiceGender.female, 'es-US')
        .voice
        ?.name, 'es-es-x-eea-local');
  });

  test('Sin una voz del género pedido ajusta el tono', () {
    const voices = [TtsVoice('es-es-x-eea-local', 'es-ES')];
    final male = chooseVoice(voices, VoiceGender.male, 'es-ES');
    expect(male.voice, isNull);
    expect(male.pitch, lessThan(1.0));
    expect(male.usesPitchOnly, isTrue);
    final female = chooseVoice(const [], VoiceGender.female, 'es-ES');
    expect(female.pitch, greaterThan(1.0));
  });
}
