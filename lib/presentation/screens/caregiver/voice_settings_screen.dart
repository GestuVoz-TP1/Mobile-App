import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/settings.dart';
import '../../../infrastructure/tts/tts_service.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Comunicacion · Voz y reproduccion (mockup 11, HU017): CONFIGURACION_VOZ
/// del perfil activo. Los cambios se aplican al guardar.
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
      setState(() => _error = e.message); // HU017, criterio 2
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final voiceItems = [
      const DropdownMenuItem<String?>(
          value: null, child: Text('Voz del dispositivo')),
      for (final v in _voices)
        DropdownMenuItem<String?>(
            value: v.name, child: Text('${v.name} · ${v.locale}')),
    ];
    final selectedVoice =
        _voices.any((v) => v.name == _draft.voiceType) ? _draft.voiceType : null;
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
          padding: const EdgeInsets.all(Insets.md),
          children: [
            if (!session.ttsAvailable) ...[
              const StatusNote(
                'Este dispositivo no tiene un motor de voz disponible. Los '
                'mensajes se mostrarán solo en pantalla.',
                kind: NoteKind.warning,
              ),
              const SizedBox(height: Insets.md),
            ],
            const SectionTitle('Voz del mensaje'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedVoice,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Voz seleccionada',
                    prefixIcon: Icon(Icons.graphic_eq_rounded),
                  ),
                  items: voiceItems,
                  onChanged: (v) {
                    final voice =
                        _voices.where((x) => x.name == v).firstOrNull;
                    setState(() => _draft = v == null
                        ? _draft.copyWith(clearVoiceType: true)
                        : _draft.copyWith(
                            voiceType: v, language: voice?.locale));
                  },
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
