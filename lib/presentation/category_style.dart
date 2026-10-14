import 'package:flutter/material.dart';

import 'theme.dart';

/// Estilo visual de cada categoria semilla (emoji y pastel). Son datos de
/// presentacion: CATEGORIA no tiene columnas de icono ni color en el modelo,
/// por eso se resuelven aqui por `id_categoria` (los emojis son los que ya
/// usaba el prototipo).
class CategoryStyle {
  final String emoji;
  final Color background;
  final Color accent;

  const CategoryStyle(this.emoji, this.background, this.accent);

  static const _fallback =
      CategoryStyle('🗂️', AppColors.mint, AppColors.mintAccent);

  static const Map<int, CategoryStyle> _byId = {
    1: CategoryStyle('🙋', AppColors.blue, AppColors.blueAccent), // Necesidades
    2: CategoryStyle('😊', AppColors.yellow, AppColors.yellowAccent), // Emociones
    3: CategoryStyle('🩹', AppColors.pink, AppColors.pinkAccent), // Salud
    4: CategoryStyle('🧼', AppColors.mint, AppColors.mintAccent), // Higiene
    5: CategoryStyle('🍎', AppColors.peach, AppColors.peachAccent), // Comida
    6: CategoryStyle('⚽', AppColors.mint, AppColors.mintAccent), // Actividades
    7: CategoryStyle('👨‍👩‍👧', AppColors.lilac, AppColors.lilacAccent), // Personas
    8: CategoryStyle('🏫', AppColors.blue, AppColors.blueAccent), // Lugares
    9: CategoryStyle('✋', AppColors.pink, AppColors.pinkAccent), // Social
    10: CategoryStyle('🕒', AppColors.lilac, AppColors.lilacAccent), // Rutina
  };

  static CategoryStyle of(int categoryId) => _byId[categoryId] ?? _fallback;
}
