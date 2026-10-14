import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/communication.dart';

/// Muestra el "dibujo" de un pictograma: la imagen subida por el tutor
/// (PICTOGRAMA.imagen) si existe, o el emoji del pictograma semilla. Se usa en
/// todas las pantallas para que semilla y personalizados se vean igual.
class PictoVisual extends StatelessWidget {
  final Pictogram pictogram;
  final double size;

  /// true = la imagen ocupa todo el espacio disponible.
  final bool fill;

  const PictoVisual({
    super.key,
    required this.pictogram,
    this.size = 52,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) => PictoGlyph(
        image: pictogram.hasImage ? pictogram.image : null,
        emoji: pictogram.emoji,
        size: size,
        fill: fill,
      );
}

/// Variante a partir de datos sueltos (historial, gestos).
class PictoGlyph extends StatelessWidget {
  final Uint8List? image;
  final String? emoji;
  final double size;
  final bool fill;

  const PictoGlyph({
    super.key,
    this.image,
    this.emoji,
    this.size = 52,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img != null && img.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(fill ? 0 : size * 0.18),
        child: Image.memory(
          img,
          width: fill ? double.infinity : size,
          height: fill ? double.infinity : size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _emoji(),
        ),
      );
    }
    return _emoji();
  }

  Widget _emoji() => Text(emoji ?? '🖼️',
      style: TextStyle(fontSize: size, height: 1.1),
      textAlign: TextAlign.center);
}
