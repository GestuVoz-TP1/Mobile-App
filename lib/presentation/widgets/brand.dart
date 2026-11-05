import 'package:flutter/material.dart';

import '../theme.dart';

class GestuVozLogo extends StatelessWidget {
  final double size;
  const GestuVozLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/brand/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'GestuVoz',
      ),
    );
  }
}

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
