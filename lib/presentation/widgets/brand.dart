import 'package:flutter/material.dart';

import '../theme.dart';

/// Isotipo de GestuVoz (mockup 1): mano sobre un cuadrado turquesa.
class GestuVozLogo extends StatelessWidget {
  final double size;
  const GestuVozLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text('🤟', style: TextStyle(fontSize: size * 0.52)),
    );
  }
}

/// Wordmark "GestuVoz".
class GestuVozWordmark extends StatelessWidget {
  final double fontSize;
  const GestuVozWordmark({super.key, this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    return Text(
      'GestuVoz',
      style: TextStyle(
        fontFamily: 'Baloo2',
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryDark,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Logo + nombre en una fila.
class GestuVozBrand extends StatelessWidget {
  final double size;
  const GestuVozBrand({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestuVozLogo(size: size),
          const SizedBox(width: 12),
          GestuVozWordmark(fontSize: size * 0.62),
        ],
      );
}
