import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/ml.dart';

/// Lee un [GestureFrame] (YUV 420 del sensor) como imagen RGB derecha, sin
/// convertir el fotograma completo: solo se muestrean los pixeles que piden
/// el detector de palmas y el clasificador.
class UprightImage {
  UprightImage(this.frame)
      : width = frame.rotation % 180 == 0 ? frame.width : frame.height,
        height = frame.rotation % 180 == 0 ? frame.height : frame.width;

  final GestureFrame frame;
  final int width;
  final int height;

  /// Escribe en [out] (a partir de [offset]) el color RGB del punto (x, y)
  /// de la imagen derecha, en el rango 0-255. Fuera de la imagen: negro.
  void sample(double x, double y, Float32List out, int offset) {
    final f = frame;
    final w = f.width, h = f.height;
    double sx, sy;
    switch (f.rotation % 360) {
      case 90:
        sx = y;
        sy = h - 1 - x;
      case 180:
        sx = w - 1 - x;
        sy = h - 1 - y;
      case 270:
        sx = w - 1 - y;
        sy = x;
      default:
        sx = x;
        sy = y;
    }
    if (sx < 0 || sy < 0 || sx > w - 1 || sy > h - 1) {
      out[offset] = 0;
      out[offset + 1] = 0;
      out[offset + 2] = 0;
      return;
    }
    // Luminancia: bilineal. Color: vecino mas cercano.
    final stride = f.yRowStride > 0 ? f.yRowStride : w;
    final x0 = sx.floor(), y0 = sy.floor();
    final x1 = math.min(x0 + 1, w - 1), y1 = math.min(y0 + 1, h - 1);
    final ax = sx - x0, ay = sy - y0;
    final yb = f.bytes;
    final top = yb[y0 * stride + x0] * (1 - ax) + yb[y0 * stride + x1] * ax;
    final bottom = yb[y1 * stride + x0] * (1 - ax) + yb[y1 * stride + x1] * ax;
    final lum = top * (1 - ay) + bottom * ay;
    if (!f.hasColor) {
      out[offset] = lum;
      out[offset + 1] = lum;
      out[offset + 2] = lum;
      return;
    }
    final uvIndex = (sy.round() >> 1) * f.uvRowStride +
        (sx.round() >> 1) * f.uvPixelStride;
    final u = f.uPlane![math.min(uvIndex, f.uPlane!.length - 1)] - 128.0;
    final v = f.vPlane![math.min(uvIndex, f.vPlane!.length - 1)] - 128.0;
    out[offset] = (lum + 1.402 * v).clamp(0.0, 255.0);
    out[offset + 1] = (lum - 0.344136 * u - 0.714136 * v).clamp(0.0, 255.0);
    out[offset + 2] = (lum + 1.772 * u).clamp(0.0, 255.0);
  }

  /// Recorte cuadrado de lado [side] centrado en ([cx], [cy]), redimensionado
  /// a [size] x [size] pixeles RGB (0-255), en formato [1, size, size, 3].
  Float32List squareCrop(double cx, double cy, double side, int size) {
    final out = Float32List(size * size * 3);
    final step = side / size;
    final left = cx - side / 2, top = cy - side / 2;
    var o = 0;
    for (var j = 0; j < size; j++) {
      final y = top + (j + 0.5) * step;
      for (var i = 0; i < size; i++) {
        sample(left + (i + 0.5) * step, y, out, o);
        o += 3;
      }
    }
    return out;
  }
}

/// Palma detectada, en pixeles de la imagen derecha.
class Palm {
  const Palm({
    required this.cx,
    required this.cy,
    required this.size,
    required this.wristX,
    required this.wristY,
    required this.middleX,
    required this.middleY,
    required this.score,
  });

  final double cx, cy, size;

  /// Muñeca y base del dedo medio: indican hacia donde estan los dedos.
  final double wristX, wristY, middleX, middleY;
  final double score;

  /// Caja cuadrada de la mano completa (cx, cy, lado). La palma se agranda
  /// y se desplaza hacia los dedos; los factores se ajustaron con imagenes
  /// de prueba de HaGRIDv2 para parecerse a los recortes del entrenamiento.
  (double, double, double) handBox({double scale = 3.0, double shift = 0.5}) {
    final dx = middleX - wristX, dy = middleY - wristY;
    final n = math.sqrt(dx * dx + dy * dy);
    final ux = n > 0 ? dx / n : 0.0, uy = n > 0 ? dy / n : -1.0;
    return (cx + ux * shift * size, cy + uy * shift * size, size * scale);
  }
}

/// Decodifica la salida del detector de palmas de MediaPipe
/// (`palm_detection_lite.tflite`, entrada 192 x 192).
class PalmDecoder {
  PalmDecoder({this.minScore = 0.3, this.maxPalms = 2}) : _anchors = _build();

  static const inputSize = 192;
  final double minScore;
  final int maxPalms;
  final Float32List _anchors;

  int get anchorCount => _anchors.length ~/ 2;

  /// Anclas SSD: capas con pasos 8 (2 anclas por celda) y 16 (6 por celda).
  static Float32List _build() {
    final a = <double>[];
    for (final (stride, perCell) in const [(8, 2), (16, 6)]) {
      final g = inputSize ~/ stride;
      for (var y = 0; y < g; y++) {
        for (var x = 0; x < g; x++) {
          for (var k = 0; k < perCell; k++) {
            a
              ..add((x + 0.5) / g)
              ..add((y + 0.5) / g);
          }
        }
      }
    }
    return Float32List.fromList(a);
  }

  /// Entrada del detector: la imagen completa con bordes negros para hacerla
  /// cuadrada, a 192 x 192 y en el rango 0-1.
  Float32List input(UprightImage img) {
    final side = math.max(img.width, img.height).toDouble();
    final t = img.squareCrop(img.width / 2, img.height / 2, side, inputSize);
    for (var i = 0; i < t.length; i++) {
      t[i] /= 255.0;
    }
    return t;
  }

  /// [regressors]: [2016 x 18], [scores]: [2016] (logits).
  List<Palm> decode(
      Float32List regressors, Float32List scores, UprightImage img) {
    final side = math.max(img.width, img.height).toDouble();
    final ox = (side - img.width) / 2, oy = (side - img.height) / 2;
    final candidates = <(int, double)>[];
    for (var i = 0; i < anchorCount; i++) {
      final s = 1 / (1 + math.exp(-scores[i].clamp(-100.0, 100.0)));
      if (s >= minScore) candidates.add((i, s));
    }
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    final palms = <Palm>[];
    final boxes = <List<double>>[];
    for (final (i, s) in candidates) {
      final r = i * 18;
      final ax = _anchors[2 * i], ay = _anchors[2 * i + 1];
      final cx = regressors[r] / inputSize + ax;
      final cy = regressors[r + 1] / inputSize + ay;
      final bw = regressors[r + 2] / inputSize;
      final bh = regressors[r + 3] / inputSize;
      final box = [cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2];
      if (boxes.any((b) => _iou(b, box) > 0.3)) continue;
      boxes.add(box);
      double px(double v) => v * side - ox;
      double py(double v) => v * side - oy;
      palms.add(Palm(
        cx: px(cx),
        cy: py(cy),
        size: math.max(bw, bh) * side,
        wristX: px(regressors[r + 4] / inputSize + ax),
        wristY: py(regressors[r + 5] / inputSize + ay),
        middleX: px(regressors[r + 8] / inputSize + ax),
        middleY: py(regressors[r + 9] / inputSize + ay),
        score: s,
      ));
      if (palms.length == maxPalms) break;
    }
    return palms;
  }

  static double _iou(List<double> a, List<double> b) {
    final ix = math.max(0.0, math.min(a[2], b[2]) - math.max(a[0], b[0]));
    final iy = math.max(0.0, math.min(a[3], b[3]) - math.max(a[1], b[1]));
    final inter = ix * iy;
    final union = (a[2] - a[0]) * (a[3] - a[1]) +
        (b[2] - b[0]) * (b[3] - b[1]) -
        inter;
    return union > 0 ? inter / union : 0;
  }
}

/// Union de dos cajas de mano (gestos con las dos manos), con margen.
(double, double, double) unionBox(
    (double, double, double) a, (double, double, double) b,
    {double margin = 1.1}) {
  final l = math.min(a.$1 - a.$3 / 2, b.$1 - b.$3 / 2);
  final t = math.min(a.$2 - a.$3 / 2, b.$2 - b.$3 / 2);
  final r = math.max(a.$1 + a.$3 / 2, b.$1 + b.$3 / 2);
  final btm = math.max(a.$2 + a.$3 / 2, b.$2 + b.$3 / 2);
  return ((l + r) / 2, (t + btm) / 2, math.max(r - l, btm - t) * margin);
}
