import 'package:flutter/material.dart';

import '../../domain/communication.dart';
import '../theme.dart';
import 'picto_visual.dart';

/// Celda de pictograma (mockup 6): tarjeta pastel del color de su categoria,
/// imagen grande, texto corto, "rebote" al pulsar y borde + icono cuando esta
/// seleccionada (el estado no depende solo del color).
class PictoTile extends StatefulWidget {
  final Pictogram pictogram;
  final Color background;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const PictoTile({
    super.key,
    required this.pictogram,
    required this.background,
    required this.accent,
    required this.onTap,
    this.selected = false,
  });

  @override
  State<PictoTile> createState() => _PictoTileState();
}

class _PictoTileState extends State<PictoTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pictogram;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: p.name,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: const Duration(milliseconds: 90),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: widget.background,
                    borderRadius: BorderRadius.circular(Radii.tile),
                    border: Border.all(
                      color: widget.selected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: p.hasImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: PictoVisual(pictogram: p, fill: true),
                              )
                            : FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: PictoVisual(pictogram: p, size: 56),
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 22,
                        child: FittedBox(
                          child: Text(
                            p.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
