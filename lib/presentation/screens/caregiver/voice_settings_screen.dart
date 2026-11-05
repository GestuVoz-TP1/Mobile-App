import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/settings.dart';
import '../../../infrastructure/tts/tts_service.dart';
import '../../controllers/session_controller.dart';
import '../../responsive.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  late VoiceConfiguration _draft;
  List<TtsVoice> _voices = const [];
  bool _saving = false;
  String? _error;
  String? _notice;

  static final _rateSteps = <double, String>{
    0.3: 'Lenta',
    0.45: 'Normal',
    0.6: 'Rápida',
  };

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionController>();
    _draft = s.voice ?? VoiceConfiguration(profileId: s.activeProfile!.id!);
    s.availableVoices().then((v) {
      if (mounted) setState(() => _voices = v);
    });
  }

  String _rateLabel(double r) {
    final nearest = _rateSteps.keys
        .reduce((a, b) => (a - r).abs() <= (b - r).abs() ? a : b);
    return _rateSteps[nearest]!;
  }

  Future<void> _test() async {
    final s = context.read<SessionController>();
    final name = s.activeProfile?.child.name.split(' ').first ?? '';
    final ok = await s.previewVoice(_draft, 'Hola, soy $name');
    await s.restoreVoice();
    if (!mounted) return;
    setState(() => _notice = ok
        ? null
        : 'No se pudo reproducir la voz. Revisa que el dispositivo tenga un '
            'motor de texto a voz en español.');
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().saveVoice(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferencias de voz guardadas')));
        Navigator.of(context).pop();
      }
    } on DomainException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.activeProfile;
    final childName = profile?.child.name.split(' ').first ?? '';
    final childGender = profile?.child.gender;
    final selected = switch (_draft.voiceType) {
      VoiceTypes.female => VoiceTypes.female,
      VoiceTypes.male => VoiceTypes.male,
      _ => VoiceTypes.automatic,
    };
    final gender = _draft.genderFor(childGender);
    final choice = chooseVoice(_voices, gender, _draft.language);
    final genderName = switch (gender) {
      VoiceGender.female => 'femenina',
      VoiceGender.male => 'masculina',
      null => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comunicación'),
            Text('Voz y reproducción',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: contentPadding(context),
          children: [
            if (!session.ttsAvailable) ...[
              const StatusNote(
                'Este dispositivo no tiene un motor de voz disponible. Los '
                'mensajes se mostrarán solo en pantalla.',
                kind: NoteKind.warning,
              ),
              const SizedBox(height: Insets.md),
            ],
            const SectionTitle('Tipo de voz'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: VoiceTypes.automatic,
                            label: Text('Automática')),
                        ButtonSegment(
                            value: VoiceTypes.female, label: Text('Femenina')),
                        ButtonSegment(
                            value: VoiceTypes.male, label: Text('Masculina')),
                      ],
                      selected: {selected},
                      onSelectionChanged: (v) => setState(() => _draft =
                          _draft.copyWith(
                              voiceType: v.first,
                              language: VoiceLimits.defaultLanguage)),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      selected != VoiceTypes.automatic
                          ? 'Se usará siempre la voz $genderName.'
                          : genderName != null
                              ? 'Según el perfil de $childName se usa la voz '
                                  '$genderName. Si cambias el género en el '
                                  'perfil, la voz se ajusta sola.'
                              : 'El perfil de $childName no indica el género, '
                                  'así que se usa la voz del dispositivo. '
                                  'Puedes indicarlo en Perfil del niño.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    if (_voices.isNotEmpty && choice.usesPitchOnly) ...[
                      const SizedBox(height: Insets.sm),
                      StatusNote(
                        'Este dispositivo no tiene una voz $genderName en '
                        'español. Se usará la voz disponible con un tono '
                        '${gender == VoiceGender.male ? 'más grave' : 'más agudo'}.',
                        kind: NoteKind.warning,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed_rounded),
                        const SizedBox(width: Insets.sm),
                        const Expanded(
                            child: Text('Velocidad',
                                style: TextStyle(fontSize: 17))),
                        Chip(label: Text(_rateLabel(_draft.rate))),
                      ],
                    ),
                    Slider(
                      value: _draft.rate.clamp(
                          VoiceLimits.minRate, VoiceLimits.maxRate),
                      min: VoiceLimits.minRate,
                      max: VoiceLimits.maxRate,
                      divisions: 12,
                      label: _rateLabel(_draft.rate),
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(rate: v)),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Lenta'), Text('Rápida')],
                    ),
                    const SizedBox(height: Insets.md),
                    Row(
                      children: [
                        const Icon(Icons.volume_up_outlined),
                        const SizedBox(width: Insets.sm),
                        const Expanded(
                            child:
                                Text('Volumen', style: TextStyle(fontSize: 17))),
                        Text('${(_draft.volume * 100).round()} %',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Slider(
                      value: _draft.volume.clamp(
                          VoiceLimits.minVolume, VoiceLimits.maxVolume),
                      min: VoiceLimits.minVolume,
                      max: VoiceLimits.maxVolume,
                      divisions: 9,
                      label: '${(_draft.volume * 100).round()} %',
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(volume: v)),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Bajo'), Text('Alto')],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Card(
              child: SwitchListTile(
                title: const Text('Reproducir voz'),
                subtitle: const Text(
                    'Leer en voz alta el mensaje del pictograma o del gesto'),
                value: _draft.voiceEnabled,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(voiceEnabled: v)),
              ),
            ),
            const SizedBox(height: Insets.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.primarySoft),
              onPressed: _test,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                  'Probar voz: “Hola, soy ${session.activeProfile?.child.name.split(' ').first ?? ''}”'),
            ),
            if (_notice != null) ...[
              const SizedBox(height: Insets.sm),
              StatusNote(_notice!, kind: NoteKind.error),
            ],
            if (_error != null) ...[
              const SizedBox(height: Insets.sm),
              StatusNote(_error!, kind: NoteKind.error),
            ],
            const SizedBox(height: Insets.md),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar preferencias'),
            ),
          ],
        ),
      ),
    );
  }
}
