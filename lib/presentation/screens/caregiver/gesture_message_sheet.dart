import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/communication_service.dart';
import '../../../application/gesture_service.dart';
import '../../../domain/communication.dart';
import '../../../domain/gesture.dart';
import '../../controllers/communication_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picto_visual.dart';
import 'vocabulary_screen.dart';

/// Hoja para adaptar lo que comunica un gesto en el perfil activo: su mensaje
/// y su pictograma. El gesto no cambia, porque es lo que reconoce el modelo.
/// Devuelve true si hubo cambios.
class GestureMessageSheet extends StatefulWidget {
  final int profileId;
  final GestureMessage current;

  const GestureMessageSheet({
    super.key,
    required this.profileId,
    required this.current,
  });

  @override
  State<GestureMessageSheet> createState() => _GestureMessageSheetState();
}

class _GestureMessageSheetState extends State<GestureMessageSheet> {
  late final TextEditingController _message =
      TextEditingController(text: widget.current.message);
  late Pictogram? _pictogram = widget.current.pictogram;
  bool _busy = false;
  String? _error;

  Gesture get _gesture => widget.current.gesture;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _choosePictogram() async {
    final chosen = await showModalBottomSheet<Pictogram>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PictogramPicker(
        profileId: widget.profileId,
        service: context.read<CommunicationService>(),
      ),
    );
    if (!mounted) return;
    context.read<CommunicationController>().invalidate();
    if (chosen != null) setState(() => _pictogram = chosen);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<GestureService>().saveMessage(
            widget.profileId,
            _gesture,
            message: _message.text,
            pictogramId: _pictogram?.id,
          );
      if (mounted) Navigator.pop(context, true);
    } on DomainException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo guardar el cambio.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    await context.read<GestureService>().resetMessage(widget.profileId, _gesture);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final picto = _pictogram;
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.lg,
        right: Insets.lg,
        top: Insets.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mensaje de ${_gesture.name}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: Insets.xs),
            const Text('El gesto se hace igual. Cambia lo que la app dice y '
                'muestra para este perfil.'),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _message,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Mensaje de voz'),
            ),
            const SizedBox(height: Insets.xs),
            const Text('Pictograma',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: Insets.xs),
            Row(
              children: [
                if (picto != null) ...[
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: PictoVisual(
                        pictogram: picto, size: 36, fill: picto.hasImage),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(child: Text(picto.name)),
                ] else
                  const Expanded(child: Text('Sin pictograma')),
                TextButton(
                  onPressed: _choosePictogram,
                  child: const Text('Cambiar'),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            const StatusNote(
                'Elige un mensaje que tenga sentido con este gesto. Los '
                'registros anteriores del historial conservan su mensaje.',
                kind: NoteKind.warning),
            if (_error != null) ...[
              const SizedBox(height: Insets.sm),
              StatusNote(_error!, kind: NoteKind.error),
            ],
            const SizedBox(height: Insets.md),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Guardar'),
            ),
            if (widget.current.isCustomized)
              TextButton(
                onPressed: _busy ? null : _reset,
                child: const Text('Volver al original'),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elige un pictograma del catalogo del perfil o crea uno con imagen propia.
class _PictogramPicker extends StatefulWidget {
  final int profileId;
  final CommunicationService service;

  const _PictogramPicker({required this.profileId, required this.service});

  @override
  State<_PictogramPicker> createState() => _PictogramPickerState();
}

class _PictogramPickerState extends State<_PictogramPicker> {
  final _search = TextEditingController();
  List<Pictogram> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.service.catalog(widget.profileId);
      if (mounted) {
        setState(() {
          _items = [for (final i in items) i.pictogram];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los pictogramas.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _createOwn() async {
    final categories = await widget.service.categories();
    if (!mounted) return;
    Pictogram? created;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PictogramEditorSheet(
        existing: null,
        categories: categories,
        profileId: widget.profileId,
        service: widget.service,
        onCreated: (p) => created = p,
      ),
    );
    if (created != null && mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final visible = _items
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.message.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.md,
          right: Insets.md,
          top: Insets.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Elige un pictograma',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: _createOwn,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Usar mi propia imagen'),
            ),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Buscar pictograma',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: _error != null
                  ? RetryPanel(message: _error!, onRetry: _load)
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final p = visible[i];
                            return ListTile(
                              leading: SizedBox(
                                width: 44,
                                height: 44,
                                child: PictoVisual(
                                    pictogram: p,
                                    size: 30,
                                    fill: p.hasImage),
                              ),
                              title: Text(p.name),
                              subtitle: Text(p.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () => Navigator.pop(context, p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
