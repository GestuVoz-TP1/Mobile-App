import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/gesture_service.dart';
import '../../../domain/gesture.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picto_visual.dart';
import 'gesture_message_sheet.dart';

/// Gestos que reconoce la aplicacion con su referencia visual, intencion y
/// mensaje. Las instrucciones, y el mensaje y el pictograma de cada gesto en el
/// perfil activo, son editables.
class GesturesCatalogScreen extends StatefulWidget {
  const GesturesCatalogScreen({super.key});

  @override
  State<GesturesCatalogScreen> createState() => _GesturesCatalogScreenState();
}

class _GesturesCatalogScreenState extends State<GesturesCatalogScreen> {
  late Future<List<(Gesture, GestureMessage?)>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  int? get _profileId =>
      context.read<SessionController>().activeProfile?.id;

  Future<List<(Gesture, GestureMessage?)>> _load() async {
    final service = context.read<GestureService>();
    final gestures = await service.catalog();
    final profileId = _profileId;
    return [
      for (final g in gestures)
        (g, profileId == null ? null : await service.messageFor(profileId, g)),
    ];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _editInstructions(Gesture g) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InstructionsSheet(gesture: g),
    );
    if (text != null && mounted) {
      await context.read<GestureService>().updateInstructions(g.id, text);
      _reload();
    }
  }

  Future<void> _editMessage(GestureMessage current) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          GestureMessageSheet(profileId: _profileId!, current: current),
    );
    if (changed == true && mounted) {
      context.read<CommunicationController>().invalidate();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestos disponibles')),
      body: SafeArea(
        child: FutureBuilder<List<(Gesture, GestureMessage?)>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return RetryPanel(
                message: 'No se pudo cargar el catálogo de gestos.',
                onRetry: _reload,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const EmptyState(
                  emoji: '✋', title: 'Aún no hay gestos definidos');
            }
            return ListView(
              padding: const EdgeInsets.all(Insets.md),
              children: [
                for (final (g, chosen) in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(g.visualRepresentation ?? '✋',
                                      style: const TextStyle(fontSize: 36)),
                                ),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(g.name,
                                          style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800)),
                                      if (chosen != null)
                                        Text('Mensaje: “${chosen.message}”',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                      if (chosen?.isCustomized ?? false) ...[
                                        const SizedBox(height: Insets.xs),
                                        const TagBadge('PERSONALIZADO'),
                                      ],
                                    ],
                                  ),
                                ),
                                if (chosen?.pictogram != null)
                                  Container(
                                    width: 48,
                                    height: 48,
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.bg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: PictoVisual(
                                        pictogram: chosen!.pictogram!,
                                        size: 28,
                                        fill: chosen.pictogram!.hasImage),
                                  ),
                              ],
                            ),
                            const SizedBox(height: Insets.sm),
                            Text('Instrucciones',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            if (g.hasInstructions)
                              for (final step in g.instructionSteps)
                                Text('• $step')
                            else
                              const Text('Sin instrucciones registradas.'),
                            const SizedBox(height: Insets.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('Editar:'),
                                if (chosen != null)
                                  TextButton.icon(
                                    onPressed: () => _editMessage(chosen),
                                    icon: const Icon(
                                        Icons.record_voice_over_outlined),
                                    label: const Text('Mensaje'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _editInstructions(g),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Instrucciones'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Hoja para editar las instrucciones de un gesto. Es duena de su
/// controlador y lo libera al cerrarse. Devuelve el texto o null si se cancela.
class _InstructionsSheet extends StatefulWidget {
  final Gesture gesture;
  const _InstructionsSheet({required this.gesture});

  @override
  State<_InstructionsSheet> createState() => _InstructionsSheetState();
}

class _InstructionsSheetState extends State<_InstructionsSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.gesture.instructions ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          top: Insets.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Instrucciones: ${widget.gesture.name}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: Insets.xs),
            const Text('Escribe un paso por línea. Se mostrarán al niño '
                'antes de usar la cámara.'),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _ctrl,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: '1. Levanta tu mano\n2. …',
              ),
            ),
            const SizedBox(height: Insets.md),
            FilledButton(
              onPressed: () => Navigator.pop(context, _ctrl.text),
              child: const Text('Guardar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
}
