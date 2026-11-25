import 'package:flutter/material.dart';

import 'theme.dart';

class CategoryStyle {
  final String emoji;
  final Color background;
  final Color accent;

  const CategoryStyle(this.emoji, this.background, this.accent);

  static const _fallback =
      CategoryStyle('🗂️', AppColors.mint, AppColors.mintAccent);

  static const Map<int, CategoryStyle> _byId = {
    1: CategoryStyle('🙋', AppColors.blue, AppColors.blueAccent),
    2: CategoryStyle('😊', AppColors.yellow, AppColors.yellowAccent),
    3: CategoryStyle('🩹', AppColors.pink, AppColors.pinkAccent),
    4: CategoryStyle('🧼', AppColors.mint, AppColors.mintAccent),
    5: CategoryStyle('🍎', AppColors.peach, AppColors.peachAccent),
    6: CategoryStyle('⚽', AppColors.mint, AppColors.mintAccent),
    7: CategoryStyle('👨‍👩‍👧', AppColors.lilac, AppColors.lilacAccent),
    8: CategoryStyle('🏫', AppColors.blue, AppColors.blueAccent),
    9: CategoryStyle('✋', AppColors.pink, AppColors.pinkAccent),
    10: CategoryStyle('🕒', AppColors.lilac, AppColors.lilacAccent),
  };

  static CategoryStyle of(int categoryId) => _byId[categoryId] ?? _fallback;
}
