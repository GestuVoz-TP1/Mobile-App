import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/consent.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Privacidad del perfil activo:
/// - HU029: informacion sobre los datos tratados y su finalidad (OB2).
/// - HU027: otorgar / no otorgar el consentimiento.
/// - HU028: retirar el consentimiento (con confirmacion).
///
/// [onboarding] = se muestra justo despues de crear el perfil.
class ConsentScreen extends StatefulWidget {
  final bool onboarding;
  const ConsentScreen({super.key, this.onboarding = false});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _busy = false;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    if (!widget.onboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
  }

  /// HU029, criterio 2: si no puede cargarse, se informa y se reintenta.
  Future<void> _reload() async {
    setState(() => _loadError = false);
    try {
      await context.read<SessionController>().reloadConsent();
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  Future<void> _decide(bool granted) async {
    setState(() => _busy = true);
    try {
      await context.read<SessionController>().decideConsent(granted: granted);
      if (mounted && !widget.onboarding) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(granted
                ? 'Consentimiento otorgado'
                : 'Decisión registrada: consentimiento no otorgado')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final ok = await confirmDialog(
      context,
      title: 'Retirar consentimiento',
      message: 'Desde ahora no se registrarán nuevas interacciones y no se '
          'podrá usar la cámara para reconocer gestos. El tablero de '
          'pictogramas seguirá disponible. Los datos ya registrados no se '
          'eliminan.',
      confirmLabel: 'Retirar',
      destructive: true,
    );
    if (!ok || !mounted) return; // HU028, criterio 2
    setState(() => _busy = true);
    try {
      await context.read<SessionController>().withdrawConsent();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.activeProfile;
    final consent = session.consent;
    final name = profile?.child.name ?? 'el niño';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.onboarding,
        title: Text(widget.onboarding ? 'Consentimiento' : 'Privacidad'),
      ),
      body: SafeArea(
        child: _loadError
            ? RetryPanel(
                message: 'No se pudo cargar la información de privacidad.',
                onRetry: _reload,
              )
            : ListView(
                padding: const EdgeInsets.all(Insets.lg),
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          size: 36, color: AppColors.primaryDark),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    widget.onboarding ? 'Antes de continuar' : 'Uso de los datos',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Como padre, madre o tutor, necesitamos tu decisión sobre '
                    'el tratamiento de los datos asociados a $name.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Insets.lg),
                  const _InfoCard(),
                  const SizedBox(height: Insets.md),
                  if (consent != null) _StatusCard(consent: consent),
                  if (consent != null) const SizedBox(height: Insets.md),
                  const StatusNote(
                    'Sin consentimiento vigente no se registran interacciones '
                    'ni se usa la cámara para reconocer gestos. El tablero de '
                    'pictogramas siempre está disponible.',
                    kind: NoteKind.warning,
                  ),
                  const SizedBox(height: Insets.lg),
                  if (consent?.state == ConsentState.granted) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.coral),
                      onPressed: _busy ? null : _withdraw,
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Retirar consentimiento'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _decide(true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Acepto'),
                    ),
                    if (consent == null) ...[
                      const SizedBox(height: Insets.sm),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _decide(false),
                        child: const Text('No acepto'),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// Informacion sobre los datos tratados y su finalidad (HU029). Contenido
/// tomado de OB2 (mockup de consentimiento, seccion 8.3 y RNF-02) y del
/// Project Charter (Ley N.º 29733).
class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(Insets.md),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.storage_rounded,
              title: 'Datos asociados al niño',
              text: 'Información de perfil, pictogramas e interacciones '
                  'comunicativas.',
            ),
            _InfoRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Uso para brindar apoyo',
              text: 'Los datos permiten personalizar la experiencia de '
                  'comunicación.',
            ),
            _InfoRow(
              icon: Icons.videocam_outlined,
              title: 'Cámara',
              text: 'Las imágenes para reconocer gestos se procesan en el '
                  'dispositivo y no se guardan.',
            ),
            _InfoRow(
              icon: Icons.verified_user_outlined,
              title: 'Cuidado y control',
              text: 'Puedes revisar esta información, retirar tu '
                  'consentimiento o eliminar el perfil. Tratamiento conforme '
                  'a la Ley N.º 29733 de Protección de Datos Personales.',
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.text,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(text,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatusCard extends StatelessWidget {
  final Consent consent;
  const _StatusCard({required this.consent});

  @override
  Widget build(BuildContext context) {
    final kind = switch (consent.state) {
      ConsentState.granted => NoteKind.success,
      ConsentState.notGranted => NoteKind.warning,
      ConsentState.withdrawn => NoteKind.error,
    };
    final date = consent.state == ConsentState.withdrawn &&
            consent.withdrawnAt != null
        ? 'Retirado el ${formatDate(consent.withdrawnAt!)}'
        : 'Registrado el ${formatDate(consent.registeredAt)}';
    return Semantics(
      label: 'Estado del consentimiento: ${consent.state.label}',
      child: StatusNote('Estado: ${consent.state.label} · $date', kind: kind),
    );
  }
}
