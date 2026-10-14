import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../application/communication_service.dart';
import '../../../domain/communication.dart';
import '../../category_style.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picto_visual.dart';

/// Gestion de pictogramas del perfil activo (mockup 10):
/// consultar y buscar, crear (HU012), editar (HU013), cambiar de categoria
/// (HU014), mostrar u ocultar en el tablero (HU015) y ordenar (RF-07).
class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final _search = TextEditingController();
  List<ProfilePictogram> _items = const [];
  List<PictogramCategory> _categories = const [];
  bool _onlyCustom = false;
  bool _loading = true;
  String? _error;

  int get _profileId =>
      context.read<SessionController>().activeProfile!.id!;
  CommunicationService get _service => context.read<CommunicationService>();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.catalog(_profileId);
      final cats = await _service.categories();
      if (!mounted) return;
      setState(() {
        _items = items;
        _categories = cats;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los pictogramas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _boardChanged() =>
      context.read<CommunicationController>().invalidate();

  List<ProfilePictogram> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items.where((i) {
      final p = i.pictogram;
      if (_onlyCustom && !p.isCustom) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.message.toLowerCase().contains(q);
    }).toList();
  }

  bool get _canReorder => !_onlyCustom && _search.text.trim().isEmpty;

  String _categoryName(int id) =>
      _categories.where((c) => c.id == id).firstOrNull?.name ?? '';

  Future<void> _toggle(ProfilePictogram item, bool show) async {
    await _service.setSelected(_profileId, item.pictogram.id!, show);
    _boardChanged();
    await _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    // onReorderItem ya entrega newIndex ajustado.
    final list = [..._items];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _items = list);
    final selectedIds = [
      for (final i in list)
        if (i.selected) i.pictogram.id!
    ];
    await _service.reorder(_profileId, selectedIds);
    _boardChanged();
    await _load();
  }

  Future<void> _openEditor([Pictogram? existing]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomEditor(
        existing: existing,
        categories: _categories,
        profileId: _profileId,
        service: _service,
      ),
    );
    if (changed == true) {
      _boardChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final customCount = _items.where((i) => i.pictogram.isCustom).length;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pictogramas'),
            Text('Consulta, crea y organiza',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Crear pictograma personalizado',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: Insets.sm),
        ],
      ),
      body: SafeArea(
        child: _error != null
            ? RetryPanel(message: _error!, onRetry: _load)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.md, Insets.sm, Insets.md, 0),
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Buscar pictograma',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                            value: false, label: Text('Todos · ${_items.length}')),
                        ButtonSegment(
                            value: true,
                            label: Text('Personalizados · $customCount')),
                      ],
                      selected: {_onlyCustom},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _onlyCustom = s.first),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Insets.md),
                    child: Text(
                      _canReorder
                          ? 'Activa “Mostrar” para que el pictograma aparezca '
                              'en el tablero. Arrastra ⠿ para cambiar el orden.'
                          : 'Activa “Mostrar” para que el pictograma aparezca '
                              'en el tablero.',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Expanded(
                    child: _loading && _items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : visible.isEmpty
                            ? EmptyState(
                                emoji: '🔎',
                                title: _onlyCustom && _search.text.isEmpty
                                    ? 'Aún no hay pictogramas personalizados'
                                    : 'Sin resultados',
                                action: _onlyCustom
                                    ? FilledButton.icon(
                                        onPressed: () => _openEditor(),
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text(
                                            'Crear pictograma personalizado'),
                                      )
                                    : null,
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    Insets.md, 0, Insets.md, 96),
                                buildDefaultDragHandles: false,
                                itemCount: visible.length,
                                onReorderItem: _canReorder ? _reorder : (_, _) {},
                                itemBuilder: (context, i) {
                                  final item = visible[i];
                                  return _PictogramRow(
                                    key: ValueKey(item.pictogram.id),
                                    item: item,
                                    index: i,
                                    categoryName:
                                        _categoryName(item.pictogram.categoryId),
                                    reorderable: _canReorder && item.selected,
                                    onToggle: (v) => _toggle(item, v),
                                    onEdit: () => _openEditor(item.pictogram),
                                  );
                                },
                              ),
                  ),
                ],
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear pictograma personalizado'),
      ),
    );
  }
}

class _PictogramRow extends StatelessWidget {
  final ProfilePictogram item;
  final int index;
  final String categoryName;
  final bool reorderable;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  const _PictogramRow({
    super.key,
    required this.item,
    required this.index,
    required this.categoryName,
    required this.reorderable,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final p = item.pictogram;
    final style = CategoryStyle.of(p.categoryId);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: p.hasImage
                    ? PictoVisual(pictogram: p, fill: true)
                    : PictoVisual(pictogram: p, size: 30),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        Flexible(
                          child: Text(categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ),
                        if (p.isCustom) ...[
                          const SizedBox(width: 6),
                          const TagBadge('PERSONAL'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(value: item.selected, onChanged: onToggle),
                  Text(item.selected ? 'Mostrar' : 'Oculto',
                      style: const TextStyle(fontSize: 11.5)),
                ],
              ),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
              if (reorderable)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.drag_indicator_rounded,
                        semanticLabel: 'Arrastrar para ordenar'),
                  ),
                )
              else
                const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }
}

/// Editor de pictogramas (existente, adaptado).
/// - Personalizado: imagen + mensaje obligatorios, nombre y categoria
///   (HU012 / HU013 / HU014). Cancelar conserva la version anterior.
/// - Semilla: solo se puede cambiar su categoria (HU014).
class _CustomEditor extends StatefulWidget {
  final Pictogram? existing;
  final List<PictogramCategory> categories;
  final int profileId;
  final CommunicationService service;

  const _CustomEditor({
    required this.existing,
    required this.categories,
    required this.profileId,
    required this.service,
  });

  @override
  State<_CustomEditor> createState() => _CustomEditorState();
}

class _CustomEditorState extends State<_CustomEditor> {
  late final TextEditingController _name;
  late final TextEditingController _message;
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  int? _categoryId;
  bool _busy = false;
  String? _error;

  Pictogram? get _existing => widget.existing;
  bool get _isSeed => _existing != null && !_existing!.isCustom;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _existing?.name ?? '');
    _message = TextEditingController(text: _existing?.message ?? '');
    _imageBytes = _existing?.image;
    _categoryId = _existing?.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _imageBytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la imagen.');
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_existing == null) {
        await widget.service.addCustom(
          profileId: widget.profileId,
          name: _name.text,
          message: _message.text,
          categoryId: _categoryId,
          image: _imageBytes,
        );
      } else {
        await widget.service.updatePictogram(
          _existing!,
          name: _name.text,
          message: _message.text,
          categoryId: _categoryId,
          image: _imageBytes,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on DomainException catch (e) {
      setState(() => _error = e.message); // HU012, criterio 2
    } catch (_) {
      setState(() => _error = 'No se pudo guardar el pictograma.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar pictograma',
      message: 'Se eliminará “${_existing!.name}” del catálogo.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await widget.service.deleteCustom(_existing!.id!);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error =
          'Este pictograma tiene interacciones en el historial y no se puede '
          'eliminar. Puedes ocultarlo del tablero.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _existing == null
        ? 'Nuevo pictograma'
        : (_isSeed ? 'Cambiar categoría' : 'Editar pictograma');
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
            Text(title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: Insets.md),
            if (_isSeed) ...[
              Row(
                children: [
                  PictoVisual(pictogram: _existing!, size: 44),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(_existing!.message,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ] else ...[
              const Text('Imagen *',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: Insets.sm),
              Row(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.outline, width: 2),
                    ),
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : const Icon(Icons.add_photo_alternate_outlined,
                            size: 36, color: AppColors.inkSoft),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galería'),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Cámara'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _message,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mensaje que dirá la voz *',
                  hintText: 'Ej.: Quiero mi osito',
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre corto (opcional)',
                  hintText: 'Ej.: Mi osito',
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría *'),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(
                      value: c.id,
                      child: Text('${CategoryStyle.of(c.id).emoji}  ${c.name}')),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              StatusNote(_error!, kind: NoteKind.error),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            if (_existing != null && _existing!.isCustom)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Eliminar pictograma'),
              ),
          ],
        ),
      ),
    );
  }
}
