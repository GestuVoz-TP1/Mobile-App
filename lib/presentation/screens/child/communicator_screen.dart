import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/communication_service.dart';
import '../../../domain/communication.dart';
import '../../category_style.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picto_tile.dart';
import '../../widgets/picto_visual.dart';

/// Tablero del nino (mockup 6): categorias (HU010) -> pictogramas del perfil
/// (HU007) -> "Mi mensaje" con UN pictograma, voz (HU008, HU009) y "Limpiar".
class CommunicatorScreen extends StatefulWidget {
  final int? initialCategoryId;
  final VoidCallback onBack;

  const CommunicatorScreen({
    super.key,
    this.initialCategoryId,
    required this.onBack,
  });

  @override
  State<CommunicatorScreen> createState() => _CommunicatorScreenState();
}

class _CommunicatorScreenState extends State<CommunicatorScreen> {
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CommunicationController>().loadBoard());
  }

  int? _effectiveCategory(Board board) {
    if (_categoryId != null &&
        board.categories.any((c) => c.id == _categoryId)) {
      return _categoryId;
    }
    // Primera categoria con pictogramas.
    for (final c in board.categories) {
      if ((board.byCategory[c.id] ?? const []).isNotEmpty) return c.id;
    }
    return board.categories.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final comm = context.watch<CommunicationController>();
    final session = context.watch<SessionController>();
    final cols = session.activeProfile?.preferences.pictogramColumns ?? 3;
    final board = comm.board;

    Widget content;
    if (comm.error != null) {
      content = RetryPanel(
          message: comm.error!, onRetry: () => comm.loadBoard(force: true));
    } else if (board == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (board.isEmpty) {
      // HU007, criterio 2
      content = const EmptyState(
        emoji: '🗂️',
        title: 'Todavía no hay pictogramas disponibles',
        message: 'Pide a tu tutor que agregue pictogramas.',
      );
    } else {
      final catId = _effectiveCategory(board);
      final pictos = board.byCategory[catId] ?? const <Pictogram>[];
      final style = CategoryStyle.of(catId ?? 0);
      content = Column(
        children: [
          _CategoryBar(
            categories: board.categories,
            selected: catId,
            onSelect: (id) => setState(() => _categoryId = id),
          ),
          Expanded(
            child: pictos.isEmpty
                // HU010, criterio 2
                ? const EmptyState(
                    emoji: '📭',
                    title: 'No hay opciones disponibles en esta categoría',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.md, Insets.sm, Insets.md, Insets.md),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: cols == 2 ? 1.0 : 0.92,
                    ),
                    itemCount: pictos.length,
                    itemBuilder: (context, i) {
                      final p = pictos[i];
                      return PictoTile(
                        pictogram: p,
                        background: style.background,
                        accent: style.accent,
                        selected: comm.message?.id == p.id,
                        onTap: () => comm.pick(p),
                      );
                    },
                  ),
          ),
          _MyMessage(controller: comm),
        ],
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, Insets.sm, Insets.md, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Inicio',
                  icon: const Icon(Icons.arrow_back_rounded, size: 28),
                  onPressed: widget.onBack,
                ),
                const Expanded(
                  child: Text('Quiero decir…',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                if (!session.ttsAvailable)
                  const Tooltip(
                    message: 'Sin voz: modo visual',
                    child: Icon(Icons.volume_off_outlined),
                  ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final List<PictogramCategory> categories;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          final isSel = c.id == selected;
          final style = CategoryStyle.of(c.id);
          return Semantics(
            button: true,
            selected: isSel,
            label: c.name,
            child: Material(
              color: isSel ? AppColors.primary : style.background,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelect(c.id),
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(style.emoji, style: const TextStyle(fontSize: 24)),
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : AppColors.ink)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "MI MENSAJE" (mockup 6): un solo pictograma/mensaje a la vez.
class _MyMessage extends StatelessWidget {
  final CommunicationController controller;
  const _MyMessage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = controller.message;
    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('MI MENSAJE',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.inkSoft)),
              ),
              if (p != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      visualDensity: VisualDensity.compact),
                  onPressed: controller.clearMessage,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          if (p == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.sm),
              child: Text('Toca una tarjeta',
                  style: TextStyle(fontSize: 18, color: AppColors.inkSoft)),
            )
          else ...[
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: PictoVisual(pictogram: p, size: 36)),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(p.message,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            if (controller.voiceFailed) ...[
              const SizedBox(height: Insets.sm),
              // HU009, criterio 2
              const StatusNote('No se pudo reproducir la voz.',
                  kind: NoteKind.error),
            ],
            const SizedBox(height: Insets.sm),
            FilledButton.icon(
              onPressed: controller.speakMessage,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Reproducir con voz'),
            ),
          ],
        ],
      ),
    );
  }
}
