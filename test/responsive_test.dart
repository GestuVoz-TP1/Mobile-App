import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/presentation/responsive.dart';

void main() {
  test('En el celular se respetan las columnas elegidas', () {
    for (final width in [320.0, 360.0, 412.0, 599.0]) {
      expect(boardColumns(width, 2), 2);
      expect(boardColumns(width, 3), 3);
      expect(boardColumns(width, 4), 4);
    }
  });

  test('En la tablet caben más columnas y los pictogramas no se agrandan', () {
    expect(boardColumns(800, 3), 6);
    expect(boardColumns(1280, 3), 9);
    expect(boardColumns(1280, 2), 6);
    expect(boardColumns(1280, 4), 13);
  });

  test('Tablet según el lado más corto', () {
    expect(isTabletSize(const Size(412, 915)), isFalse);
    expect(isTabletSize(const Size(915, 412)), isFalse);
    expect(isTabletSize(const Size(800, 1280)), isTrue);
    expect(isTabletSize(const Size(1280, 800)), isTrue);
  });
}
