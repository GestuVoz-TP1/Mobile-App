import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/gesture.dart';
import '../../../infrastructure/camera/camera_service.dart';
import '../../category_style.dart';
import '../../controllers/capture_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picto_visual.dart';

/// "Usar mis gestos" (D7):
/// 1. Preparacion: gestos habilitados con su representacion e instrucciones.
/// 2. "Comenzar" -> camara con "Buscando tus manos..." (mockup 7).
/// 3. Reconocido (mockup 8) o no reconocido (mockup 9).
///
/// Reconocimiento abierto: el nino hace cualquiera de los gestos habilitados.
class GestureRecognitionScreen extends StatefulWidget {
  /// HU005: abrir el tablero de pictogramas.
  final VoidCallback onUsePictograms;
  const GestureRecognitionScreen({super.key, required this.onUsePictograms});

  @override
  State<GestureRecognitionScreen> createState() =>
      _GestureRecognitionScreenState();
}

class _GestureRecognitionScreenState extends State<GestureRecognitionScreen>
    with WidgetsBindingObserver {
  late final CaptureController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = context.read<CaptureController>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.open());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Libera la camara al pasar a segundo plano (no se capta nada fuera de la
    // pantalla de reconocimiento).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _ctrl.releaseCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaptureController>();
    return switch (c.phase) {
      GesturePhase.loading =>
        const SafeArea(child: Center(child: CircularProgressIndicator())),
      GesturePhase.unavailable =>
        _Unavailable(controller: c, onUsePictograms: widget.onUsePictograms),
      GesturePhase.preparation => _Preparation(controller: c),
      GesturePhase.cameraIssue =>
        _CameraIssue(controller: c, onUsePictograms: widget.onUsePictograms),
      GesturePhase.startingCamera ||
      GesturePhase.capturing ||
      GesturePhase.simulating ||
      GesturePhase.analyzing =>
        _CameraStage(controller: c),
      GesturePhase.recognized => _Recognized(controller: c),
      GesturePhase.notRecognized =>
        _NotRecognized(controller: c, onUsePictograms: widget.onUsePictograms),
    };
  }
}

// ---------------------------------------------------------------------------
// 1. Preparacion
// ---------------------------------------------------------------------------
class _Preparation extends StatelessWidget {
  final CaptureController controller;
  const _Preparation({required this.controller});

  @override
  Widget build(BuildContext context) {
    final gestures = controller.enabledGestures;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Insets.md),
              children: [
                const Text('Usar mis gestos',
                    style:
                        TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const Text('Puedes hacer uno de estos gestos',
                    style: TextStyle(fontSize: 18, color: AppColors.inkSoft)),
                if (controller.isSimulated) ...[
                  const SizedBox(height: Insets.sm),
                  const StatusNote(
                    'Modo demostración: el reconocimiento es simulado. Aún no '
                    'existe el modelo entrenado.',
                    kind: NoteKind.warning,
                  ),
                ],
                const SizedBox(height: Insets.md),
                for (final g in gestures) _GestureCard(gesture: g),
                const SizedBox(height: Insets.sm),
                const StatusNote(
                  'Colócate frente a la cámara. Muestra tu cara y tus manos. '
                  'Busca un lugar con buena luz y haz el gesto despacio.',
                  kind: NoteKind.info,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.md, 0, Insets.md, Insets.md),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: controller.start,
                icon: const Icon(Icons.videocam_rounded, size: 28),
                label: const Text('Comenzar',
                    style: TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GestureCard extends StatelessWidget {
  final Gesture gesture;
  const _GestureCard({required this.gesture});

  @override
  Widget build(BuildContext context) {
    final steps = gesture.instructionSteps;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(gesture.visualRepresentation ?? '✋',
                  style: const TextStyle(fontSize: 44)),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(gesture.name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                      ),
                      if (gesture.isDemo) ...[
                        const SizedBox(width: 6),
                        const DemoBadge(),
                      ],
                    ],
                  ),
                  for (var i = 0; i < steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${i + 1}. ${steps[i]}',
                          style: const TextStyle(fontSize: 16)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Camara (mockup 7) + selector DEMO
// ---------------------------------------------------------------------------
class _CameraStage extends StatelessWidget {
  final CaptureController controller;
  const _CameraStage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cam = controller.camera;
    final phase = controller.phase;
    final status = switch (phase) {
      GesturePhase.startingCamera => 'Encendiendo la cámara…',
      GesturePhase.capturing => 'Buscando tus manos…',
      GesturePhase.analyzing => 'Entendiendo tu gesto…',
      _ => 'Listo',
    };
    return ColoredBox(
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cam.isReady && cam.controller != null)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: cam.controller!.value.previewSize?.height ??
                                300,
                            height: cam.controller!.value.previewSize?.width ??
                                400,
                            child: CameraPreview(cam.controller!),
                          ),
                        )
                      else
                        const ColoredBox(color: Colors.black26),
                      // Recuadro guia: mantener las manos dentro (RF-02).
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.82,
                          heightFactor: 0.72,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              border:
                                  Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (phase == GesturePhase.capturing ||
                                      phase == GesturePhase.analyzing ||
                                      phase == GesturePhase.startingCamera)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.yellowAccent),
                                    )
                                  else
                                    const Icon(Icons.check_circle_rounded,
                                        size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(status,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black38),
                          tooltip: 'Cerrar',
                          onPressed: controller.backToPreparation,
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (phase == GesturePhase.simulating)
              _DemoSelector(controller: controller)
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    Insets.lg, 0, Insets.lg, Insets.lg),
                child: Column(
                  children: [
                    Text('Colócate frente a la cámara',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                        'Muestra tu cara y tus manos. Luego realiza un gesto '
                        'con calma.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// D7: selector "DEMO — resultado simulado". Solo existe con el reconocedor
/// DEMO; no muestra porcentajes.
class _DemoSelector extends StatelessWidget {
  final CaptureController controller;
  const _DemoSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.yellowAccent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, color: AppColors.amberInk),
              SizedBox(width: 6),
              Text('DEMO — resultado simulado',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.amberInk)),
            ],
          ),
          const Text('Elige qué resultado devolverá el reconocimiento.',
              style: TextStyle(color: AppColors.amberInk)),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final g in controller.enabledGestures)
                ActionChip(
                  backgroundColor: Colors.white,
                  avatar: Text(g.visualRepresentation ?? '✋'),
                  label: Text(g.name),
                  onPressed: () =>
                      controller.chooseSimulatedOutcome(g.recognitionClass),
                ),
              ActionChip(
                backgroundColor: Colors.white,
                avatar: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('No reconocido'),
                onPressed: () => controller.chooseSimulatedOutcome(null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3a. Reconocido (mockup 8)
// ---------------------------------------------------------------------------
class _Recognized extends StatelessWidget {
  final CaptureController controller;
  const _Recognized({required this.controller});

  @override
  Widget build(BuildContext context) {
    final o = controller.outcome!;
    final style = CategoryStyle.of(o.pictogram.categoryId);
    final confidence = controller.recognizerInfo.isRealModel
        ? o.result.confidence
        : null; // en DEMO no se muestran porcentajes
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: [
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 6),
                        Text('¡Gesto reconocido!',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
                if (controller.isSimulated) ...[
                  const SizedBox(height: Insets.sm),
                  const Center(child: DemoBadge(text: 'DEMO — resultado simulado')),
                ],
                const SizedBox(height: Insets.lg),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: const BoxDecoration(
                        color: AppColors.primarySoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        color: style.background,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: FittedBox(
                                  child: PictoVisual(
                                      pictogram: o.pictogram, size: 80)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(o.pictogram.name,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                const Text('ENTENDÍ QUE QUIERES DECIR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.inkSoft)),
                Semantics(
                  liveRegion: true,
                  child: Text('“${o.intention.message}”',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w800)),
                ),
                if (confidence != null) ...[
                  const SizedBox(height: Insets.md),
                  Text('Coincidencia ${confidence.percent.round()} %',
                      textAlign: TextAlign.center),
                ],
                if (controller.voiceFailed) ...[
                  const SizedBox(height: Insets.md),
                  const StatusNote('No se pudo reproducir la voz.',
                      kind: NoteKind.error),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.md, 0, Insets.md, Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: controller.speakAgain,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Escuchar mensaje'),
                ),
                const SizedBox(height: Insets.sm),
                OutlinedButton.icon(
                  onPressed: controller.retry,
                  icon: const Icon(Icons.center_focus_strong_outlined),
                  label: const Text('Hacer otro gesto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3b. No reconocido (mockup 9)
// ---------------------------------------------------------------------------
class _NotRecognized extends StatelessWidget {
  final CaptureController controller;
  final VoidCallback onUsePictograms;
  const _NotRecognized(
      {required this.controller, required this.onUsePictograms});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: [
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(
                        color: AppColors.coralSoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🤔', style: TextStyle(fontSize: 72)),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Semantics(
                  liveRegion: true,
                  child: const Text('No entendí el gesto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: Insets.xs),
                const Text(
                    'Está bien. Colócate frente a la cámara y muéstrame tus '
                    'manos otra vez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: AppColors.inkSoft)),
                const SizedBox(height: Insets.lg),
                const StatusNote(
                    'Busca un lugar con buena luz y haz el gesto despacio.',
                    kind: NoteKind.warning),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.md, 0, Insets.md, Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: controller.retry, // HU011
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Intentar de nuevo'),
                ),
                const SizedBox(height: Insets.sm),
                OutlinedButton.icon(
                  onPressed: onUsePictograms, // HU005
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Usar pictogramas'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modalidad no disponible / problema de camara
// ---------------------------------------------------------------------------
class _Unavailable extends StatelessWidget {
  final CaptureController controller;
  final VoidCallback onUsePictograms;
  const _Unavailable(
      {required this.controller, required this.onUsePictograms});

  @override
  Widget build(BuildContext context) {
    final (title, msg) = switch (controller.unavailableReason) {
      GestureUnavailableReason.disabled => (
          'Los gestos están desactivados',
          'Pide a tu tutor que active la comunicación mediante gestos.'
        ),
      GestureUnavailableReason.noConsent => (
          'La cámara no está habilitada',
          'Para usar los gestos, tu tutor debe otorgar el consentimiento de '
              'tratamiento de datos.'
        ),
      GestureUnavailableReason.noGestures => (
          'No hay gestos habilitados',
          'Pide a tu tutor que habilite gestos en tu perfil.'
        ),
      _ => (
          'No se pudo preparar el reconocimiento',
          'Vuelve a intentarlo en un momento.'
        ),
    };
    return SafeArea(
      child: EmptyState(
        emoji: '✋',
        title: title,
        message: msg,
        action: Column(
          children: [
            FilledButton.icon(
              onPressed: onUsePictograms,
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Usar pictogramas'),
            ),
            if (controller.unavailableReason ==
                GestureUnavailableReason.error) ...[
              const SizedBox(height: Insets.sm),
              OutlinedButton(
                onPressed: controller.open,
                child: const Text('Volver a intentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CameraIssue extends StatelessWidget {
  final CaptureController controller;
  final VoidCallback onUsePictograms;
  const _CameraIssue(
      {required this.controller, required this.onUsePictograms});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: EmptyState(
        emoji: '📷',
        title: 'No se pudo usar la cámara',
        message: controller.camera.issue.howToFix,
        action: Column(
          children: [
            FilledButton.icon(
              onPressed: controller.start,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Intentar de nuevo'),
            ),
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: onUsePictograms,
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Usar pictogramas'),
            ),
          ],
        ),
      ),
    );
  }
}
