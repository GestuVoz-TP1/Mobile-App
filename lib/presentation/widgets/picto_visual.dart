import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/communication.dart';

class PictoVisual extends StatelessWidget {
  final Pictogram pictogram;
  final double size;

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
