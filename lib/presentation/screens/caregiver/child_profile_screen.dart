import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/gesture_service.dart';
import '../../../domain/child.dart';
import '../../../domain/consent.dart';
import '../../../domain/gesture.dart';
import '../../../infrastructure/camera/camera_service.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'child_edit_screen.dart';
import 'consent_screen.dart';
import 'gestures_catalog_screen.dart';

/// Perfil del nino (mockup 4): informacion basica y preferencias de
/// comunicacion del perfil activo.
class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  late CommunicationPreferences _prefs;
  late bool _voiceEnabled;
  List<Gesture> _gestures = const [];
  bool _checkingCamera = false;
  bool _saving = false;
  String? _gestureIssue;

  @override
  void initState() {
    super.initState();
    final s = context.read<SessionController>();
    _prefs = s.activeProfile!.preferences;
    _voiceEnabled = s.voice?.voiceEnabled ?? true;
    context.read<GestureService>().catalog().then((g) {
      if (mounted) setState(() => _gestures = g);
    });
  }

  bool _dirty(SessionController s) {
    final p = s.activeProfile!.preferences;
    return p.toJson() != _prefs.toJson() ||
        (s.voice?.voiceEnabled ?? true) != _voiceEnabled;
  }

  /// HU002 / HU004: preparar la modalidad de gestos.
  Future<void> _toggleGestures(bool on) async {
    setState(() => _gestureIssue = null);
    if (!on) {
      setState(() => _prefs = _prefs.copyWith(gesturesEnabled: false));
      return;
    }
    final session = context.read<SessionController>();
    if (!session.consentAllowsProcessing) {
      setState(() => _gestureIssue =
          'Para usar la cámara primero debe estar otorgado el consentimiento '
          'de tratamiento de datos de este perfil.');
      return;
    }
    // Solicita el permiso y verifica que la camara este disponible.
    setState(() => _checkingCamera = true);
    final camera = context.read<CameraService>();
    await camera.discover();
    await camera.start();
    final issue = camera.isReady ? CameraIssue.none : camera.issue;
    await camera.dispose();
    if (!mounted) return;
    setState(() {
      _checkingCamera = false;
      if (issue == CameraIssue.none) {
        _prefs = _prefs.copyWith(gesturesEnabled: true);
      } else {
        _gestureIssue = issue.howToFix; // HU002, criterio 2
      }
    });
  }

  Future<void> _save() async {
    final session = context.read<SessionController>();
    setState(() => _saving = true);
    try {
      await session.savePreferences(_prefs);
      final v = session.voice;
      if (v != null && v.voiceEnabled != _voiceEnabled) {
        await session.saveVoice(v.copyWith(voiceEnabled: _voiceEnabled));
      }
      if (!mounted) return;
      context.read<CommunicationController>().invalidate();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    } on DomainException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.activeProfile;
    if (profile == null) return const SizedBox.shrink();
    final c = profile.child;
    final dirty = _dirty(session);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(
          context,
          title: 'Descartar cambios',
          message: 'Los cambios sin guardar se perderán y se mantendrá la '
              'configuración anterior.',
          confirmLabel: 'Descartar',
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Perfil del niño'),
          actions: [
            IconButton(
              tooltip: 'Editar datos',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChildEditScreen(profile: profile))),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    children: [
                      InitialsAvatar(c.initials, radius: 34),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800)),
                            Text('${c.age} años'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Información básica'),
              Card(
                child: Column(
                  children: [
                    _InfoTile(Icons.calendar_today_outlined,
                        'Fecha de nacimiento', formatDate(c.birthDate)),
                    _InfoTile(Icons.wc_rounded, 'Género',
                        c.gender ?? 'No indicado'),
                    _InfoTile(Icons.support_outlined, 'Nivel de apoyo',
                        profile.supportLevel ?? 'No indicado'),
                  ],
                ),
              ),
              const SectionTitle('Preferencias de comunicación'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Reproducir voz'),
                      subtitle: const Text(
                          'Leer en voz alta el mensaje seleccionado'),
                      value: _voiceEnabled,
                      onChanged: (v) => setState(() => _voiceEnabled = v),
                    ),
                    ListTile(
                      title: const Text('Tamaño de los pictogramas'),
                      subtitle: Wrap(
                        spacing: Insets.sm,
                        children: [
                          for (final e in kPictogramSizeOptions.entries)
                            ChoiceChip(
                              label: Text(e.value),
                              selected: _prefs.pictogramColumns == e.key,
                              onSelected: (_) => setState(() => _prefs =
                                  _prefs.copyWith(pictogramColumns: e.key)),
                            ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Alto contraste'),
                      subtitle: const Text('Mejor visibilidad de textos'),
                      value: _prefs.highContrast,
                      onChanged: (v) => setState(
                          () => _prefs = _prefs.copyWith(highContrast: v)),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Comunicación mediante gestos'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Usar gestos'),
                      subtitle: Text(_checkingCamera
                          ? 'Verificando la cámara…'
                          : _prefs.gesturesEnabled
                              ? 'Modalidad preparada para este perfil'
                              : 'Requiere permiso de cámara'),
                      value: _prefs.gesturesEnabled,
                      onChanged: _checkingCamera ? null : _toggleGestures,
                    ),
                    if (_gestureIssue != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md, 0, Insets.md, Insets.md),
                        child: StatusNote(_gestureIssue!,
                            kind: NoteKind.error),
                      ),
                    if (_prefs.gesturesEnabled) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.md, Insets.sm, Insets.md, 0),
                        child: Text('Gestos habilitados',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ),
                      for (final g in _gestures)
                        CheckboxListTile(
                          value: _prefs.enabledGestureIds.contains(g.id),
                          secondary: Text(g.visualRepresentation ?? '✋',
                              style: const TextStyle(fontSize: 26)),
                          title: Row(
                            children: [
                              Flexible(child: Text(g.name)),
                              if (g.isDemo) ...[
                                const SizedBox(width: 6),
                                const DemoBadge(),
                              ],
                            ],
                          ),
                          onChanged: (on) {
                            final ids = {..._prefs.enabledGestureIds};
                            on == true ? ids.add(g.id) : ids.remove(g.id);
                            setState(() => _prefs = _prefs.copyWith(
                                enabledGestureIds: ids.toList()..sort()));
                          },
                        ),
                    ],
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: const Text('Ver gestos disponibles'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const GesturesCatalogScreen())),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Privacidad'),
              Card(
                child: ListTile(
                  leading: Icon(
                    session.consentAllowsProcessing
                        ? Icons.verified_user_outlined
                        : Icons.gpp_maybe_outlined,
                    color: session.consentAllowsProcessing
                        ? AppColors.success
                        : AppColors.coral,
                  ),
                  title: const Text('Consentimiento'),
                  subtitle: Text(session.consent?.state.label ?? 'Sin decisión'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ConsentScreen())),
                ),
              ),
              const SizedBox(height: Insets.lg),
              FilledButton.icon(
                onPressed: _saving || !dirty ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Guardar cambios'),
              ),
              if (dirty) ...[
                const SizedBox(height: Insets.sm),
                TextButton(
                  onPressed: () => setState(() {
                    _prefs = session.activeProfile!.preferences;
                    _voiceEnabled = session.voice?.voiceEnabled ?? true;
                    _gestureIssue = null;
                  }),
                  child: const Text('Cancelar cambios'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 17, color: AppColors.ink)),
      );
}
