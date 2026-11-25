import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

const kTabletShortestSide = 600.0;
const kMaxContentWidth = 720.0;
const _phoneReferenceWidth = 390.0;

bool isTabletSize(Size size) => size.shortestSide >= kTabletShortestSide;

int boardColumns(double width, int phoneColumns) {
  if (width < kTabletShortestSide) return phoneColumns;
  final tile = _phoneReferenceWidth / phoneColumns;
  return math.max(phoneColumns, (width / tile).floor());
}

EdgeInsets contentPadding(BuildContext context, {double base = Insets.md}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(base, (width - kMaxContentWidth) / 2);
  return EdgeInsets.fromLTRB(side, base, side, base);
}

class ContentWidth extends StatelessWidget {
  final Widget child;
  const ContentWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: child,
        ),
      );
}
