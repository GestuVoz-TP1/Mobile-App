import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/domain/ml.dart';
import 'package:gestuvoz/infrastructure/ml/hand_detection.dart';

/// Imagen derecha de [w] x [h] con un valor distinto por pixel, guardada
/// como la entrega el sensor (girada) para la [rotation] dada.
GestureFrame _frame(int w, int h, int rotation, int Function(int x, int y) v) {
  final sw = rotation % 180 == 0 ? w : h;
  final sh = rotation % 180 == 0 ? h : w;
  final y = Uint8List(sw * sh);
  for (var x = 0; x < w; x++) {
    for (var yy = 0; yy < h; yy++) {
      final (sx, sy) = switch (rotation) {
        90 => (yy, sh - 1 - x),
        180 => (sw - 1 - x, sh - 1 - yy),
        270 => (sw - 1 - yy, x),
        _ => (x, yy),
      };
      y[sy * sw + sx] = v(x, yy);
    }
  }
  final uvLength = ((sw + 1) ~/ 2) * ((sh + 1) ~/ 2);
  final uv = Uint8List(uvLength)..fillRange(0, uvLength, 128); // gris
  return GestureFrame(
    bytes: y,
    width: sw,
    height: sh,
    capturedAt: DateTime(2026),
    uPlane: uv,
    vPlane: uv,
    yRowStride: sw,
    uvRowStride: (sw + 1) ~/ 2,
    uvPixelStride: 1,
    rotation: rotation,
  );
}

void main() {
  for (final rotation in [0, 90, 180, 270]) {
    test('El fotograma girado $rotation° se lee derecho', () {
      int value(int x, int y) => 10 * y + x;
      final img = UprightImage(_frame(5, 7, rotation, value));
      expect((img.width, img.height), (5, 7));
      final out = Float32List(3);
      for (var x = 0; x < 5; x++) {
        for (var y = 0; y < 7; y++) {
          img.sample(x.toDouble(), y.toDouble(), out, 0);
          expect(out[0], closeTo(value(x, y), 1e-3), reason: '($x, $y)');
          expect(out[1], closeTo(value(x, y), 1e-3));
        }
      }
    });
  }

  test('Convierte YUV a RGB (rojo puro)', () {
    // Rojo (255, 0, 0) en YUV BT.601 completo: Y=76, U=85, V=255.
    final f = GestureFrame(
      bytes: Uint8List.fromList([76, 76, 76, 76]),
      width: 2,
      height: 2,
      capturedAt: DateTime(2026),
      uPlane: Uint8List.fromList([85]),
      vPlane: Uint8List.fromList([255]),
      uvRowStride: 1,
    );
    final out = Float32List(3);
    UprightImage(f).sample(0, 0, out, 0);
    expect(out[0], closeTo(255, 3));
    expect(out[1], closeTo(0, 3));
    expect(out[2], closeTo(0, 3));
  });

  test('Fuera de la imagen el recorte es negro', () {
    final img = UprightImage(_frame(4, 4, 0, (_, _) => 200));
    final crop = img.squareCrop(2, 2, 8, 8);
    expect(crop.length, 8 * 8 * 3);
    expect(crop[0], 0); // esquina superior izquierda, fuera
    expect(crop[(4 * 8 + 4) * 3], closeTo(200, 1e-3)); // centro
  });

  test('El detector de palmas usa 2016 anclas y decodifica la caja', () {
    final d = PalmDecoder();
    expect(d.anchorCount, 2016);
    final img = UprightImage(_frame(300, 200, 0, (_, _) => 0));
    final reg = Float32List(2016 * 18);
    final scores = Float32List(2016)..fillRange(0, 2016, -10);
    // Ancla 0: celda (0, 0) de la capa de paso 8 -> centro (4, 4) en 192 px.
    scores[0] = 5;
    reg[2] = 19.2; // ancho = 0,1 del lado
    reg[3] = 19.2;
    reg[9] = -19.2; // dedo medio arriba de la muñeca
    final palms = d.decode(reg, scores, img);
    expect(palms, hasLength(1));
    final p = palms.single;
    // Lado del cuadrado = 300; la imagen tiene 50 px de borde arriba.
    expect(p.cx, closeTo(4 / 192 * 300, 1e-3));
    expect(p.cy, closeTo(4 / 192 * 300 - 50, 1e-3));
    expect(p.size, closeTo(30, 1e-3));
    final (cx, cy, side) = p.handBox();
    expect(cx, closeTo(p.cx, 1e-3));
    expect(cy, closeTo(p.cy - 15, 1e-3)); // se desplaza hacia los dedos
    expect(side, closeTo(90, 1e-3));
  });
}
