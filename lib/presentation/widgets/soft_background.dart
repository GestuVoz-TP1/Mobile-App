import 'package:flutter/material.dart';

import '../theme.dart';

class SoftBackground extends StatelessWidget {
  final Widget child;
  const SoftBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final hc = Theme.of(context).colorScheme.onSurface == Colors.black;
    return ColoredBox(
      color: hc ? Colors.white : AppColors.bg,
      child: child,
    );
  }
}
