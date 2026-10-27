import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/ml.dart';
import '../../domain/shared.dart';
import 'hand_detection.dart';

/// Modelo real (OB2, secciones 8.1-8.3), ejecutado en el dispositivo:
///
///   fotograma -> detector de palmas (MediaPipe) -> recorte de la mano
///             -> MobileNetV3 (caracteristicas de 128 valores)
///   16 fotogramas -> LSTM -> gesto o "ninguno"
///
/// Los modelos se entrenaron con HaGRIDv2 en el repositorio ML
/// (`entrenamiento/`). Las etiquetas (`etiquetas.txt`) son los valores de
/// GESTO.clase_reconocimiento. Las imagenes solo se procesan en memoria
/// (RNF-02).
class TensorFlowLiteGestureRecognitionService
    implements GestureRecognitionService {
  TensorFlowLiteGestureRecognitionService({
    this.modelDir = 'assets/models',
    this.minConfidence = 0.85,
  });

  final String modelDir;

  /// Umbral para no comunicar un mensaje incorrecto (HU006, criterio 2).
  final double minConfidence;

  static const _cropSize = 224;
  static const _sequenceLength = 16;
  static const _noGesture = 'ninguno';

  Interpreter? _palm;
  Interpreter? _frame;
  Interpreter? _sequence;
  List<String> _labels = const [];
  final _decoder = PalmDecoder();
  int _featureOutput = 0;
  int _featureSize = 0;
  int _palmBoxOutput = 0;

  @override
  RecognizerInfo get info => const RecognizerInfo(
        name: 'MobileNet + LSTM (TensorFlow Lite)',
        isRealModel: true,
        notes: 'Entrenado con HaGRIDv2; pendiente de validar con videos '
            'propios.',
      );

  @override
  bool get isLoaded => _sequence != null;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    final options = InterpreterOptions()..threads = 4;
    _palm = await Interpreter.fromAsset('$modelDir/palm_detection_lite.tflite',
        options: options);
    _frame = await Interpreter.fromAsset('$modelDir/gestos_fotograma.tflite',
        options: options);
    _sequence = await Interpreter.fromAsset(
        '$modelDir/gestos_secuencia.tflite',
        options: options);
    _labels = (await rootBundle.loadString('$modelDir/etiquetas.txt'))
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // El clasificador devuelve (caracteristicas, probabilidades); el orden
    // de las salidas se identifica por su tamaño.
    final outs = _frame!.getOutputTensors();
    _featureOutput = outs[0].shape.last == _labels.length ? 1 : 0;
    _featureSize = outs[_featureOutput].shape.last;
    _palmBoxOutput = _palm!.getOutputTensors()[0].shape.last == 18 ? 0 : 1;
  }

  @override
  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  }) async {
    final watch = Stopwatch()..start();
    if (sequence.isEmpty) {
      return const GestureRecognitionResult.notRecognized();
    }
    await load();

    final features = Float32List(_sequenceLength * _featureSize);
    final frames = sequence.frames;
    for (var t = 0; t < _sequenceLength; t++) {
      // Si llegaron menos fotogramas, se repiten los ultimos.
      final frame = frames[t < frames.length ? t : frames.length - 1];
      features.setAll(t * _featureSize, _frameFeatures(frame));
      // Deja respirar a la interfaz entre fotogramas.
      await Future<void>.delayed(Duration.zero);
    }

    final probs = Float32List(_labels.length);
    _sequence!.run(features.buffer.asUint8List(), probs.buffer.asUint8List());
    var best = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }
    final label = _labels[best];
    final latency = watch.elapsedMilliseconds;
    if (label == _noGesture ||
        probs[best] < minConfidence ||
        !candidateClasses.contains(label)) {
      return GestureRecognitionResult.notRecognized(latencyMs: latency);
    }
    return GestureRecognitionResult(
      recognitionClass: label,
      confidence: Confidence(probs[best]),
      latencyMs: latency,
    );
  }

  /// Caracteristicas de un fotograma: se busca la mano y se clasifica el
  /// recorte. Con dos manos se prueba cada una y su union (gestos con ambas
  /// manos) y se queda el recorte con el gesto mas claro. Sin manos se usa
  /// la imagen completa, que el modelo reconoce como "ninguno".
  Float32List _frameFeatures(GestureFrame frame) {
    final img = UprightImage(frame);
    final palms = _detectPalms(img);
    final boxes = [for (final p in palms) p.handBox()];
    if (boxes.length == 2) boxes.add(unionBox(boxes[0], boxes[1]));
    if (boxes.isEmpty) {
      final side = (img.width < img.height ? img.width : img.height)
          .toDouble();
      boxes.add((img.width / 2, img.height / 2, side));
    }
    final noGesture = _labels.indexOf(_noGesture);
    Float32List? bestFeatures;
    var bestScore = -1.0;
    for (final (cx, cy, side) in boxes) {
      final (feat, probs) =
          _classify(img.squareCrop(cx, cy, side, _cropSize));
      var score = 0.0;
      for (var i = 0; i < probs.length; i++) {
        if (i != noGesture && probs[i] > score) score = probs[i];
      }
      if (score > bestScore) {
        bestScore = score;
        bestFeatures = feat;
      }
    }
    return bestFeatures!;
  }

  List<Palm> _detectPalms(UprightImage img) {
    final regressors = Float32List(_decoder.anchorCount * 18);
    final scores = Float32List(_decoder.anchorCount);
    _palm!.runForMultipleInputs(
      [_decoder.input(img).buffer.asUint8List()],
      {
        _palmBoxOutput: regressors.buffer.asUint8List(),
        1 - _palmBoxOutput: scores.buffer.asUint8List(),
      },
    );
    return _decoder.decode(regressors, scores, img);
  }

  (Float32List, Float32List) _classify(Float32List crop) {
    final feat = Float32List(_featureSize);
    final probs = Float32List(_labels.length);
    _frame!.runForMultipleInputs([crop.buffer.asUint8List()], {
      _featureOutput: feat.buffer.asUint8List(),
      1 - _featureOutput: probs.buffer.asUint8List(),
    });
    return (feat, probs);
  }

  @override
  Future<void> dispose() async {
    _palm?.close();
    _frame?.close();
    _sequence?.close();
    _palm = _frame = _sequence = null;
  }
}
