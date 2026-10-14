/// -------------------------------------------------------------------------
/// Bounded context: MACHINE LEARNING (reconocimiento de gestos)
///
/// La app depende solo de este puerto. OB2 define un modelo MobileNet + LSTM
/// ejecutado con TensorFlow Lite sobre SECUENCIAS de imagenes (RF-01).
///
///   GestureRecognitionService
///     ├─ TestModeGestureRecognitionService        (mientras no exista el modelo)
///     └─ TensorFlowLiteGestureRecognitionService  (cuando exista el .tflite)
///
/// Las imagenes se procesan solo en memoria y nunca se guardan (RNF-02).
/// -------------------------------------------------------------------------
library;

import 'dart:typed_data';

import 'shared.dart';

/// Un fotograma capturado por la camara (en memoria).
class GestureFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime capturedAt;

  const GestureFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.capturedAt,
  });
}

/// Secuencia de fotogramas que recibe el modelo (entrada del LSTM).
class GestureSequence {
  final List<GestureFrame> frames;
  const GestureSequence(this.frames);
  bool get isEmpty => frames.isEmpty;
}

/// Metadatos del reconocedor desplegado.
class RecognizerInfo {
  final String name;

  /// true solo si es un modelo entrenado real.
  final bool isRealModel;
  final String notes;

  const RecognizerInfo({
    required this.name,
    required this.isRealModel,
    this.notes = '',
  });
}

/// Resultado del reconocimiento.
class GestureRecognitionResult {
  /// `clase_reconocimiento` del gesto reconocido; null = no reconocido.
  final String? recognitionClass;

  /// Confianza del modelo. Solo un modelo real la informa (no se inventan
  /// porcentajes).
  final Confidence? confidence;

  final int latencyMs;

  const GestureRecognitionResult({
    required this.recognitionClass,
    this.confidence,
    this.latencyMs = 0,
  });

  const GestureRecognitionResult.notRecognized({this.latencyMs = 0})
      : recognitionClass = null,
        confidence = null;

  bool get recognized => recognitionClass != null;
}

/// Puerto: reconocimiento de gestos a partir de una secuencia de imagenes.
abstract interface class GestureRecognitionService {
  RecognizerInfo get info;
  bool get isLoaded;
  Future<void> load();

  /// [candidateClasses]: clases de los gestos habilitados para el perfil.
  /// Un resultado fuera de esta lista debe tratarse como no reconocido.
  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  });

  Future<void> dispose();
}

/// Modo de prueba del reconocedor que se usa mientras no existe el modelo
/// entrenado: quien prueba la app elige el resultado del siguiente intento.
/// Solo se ofrece en compilaciones de desarrollo. Un modelo real NO
/// implementa esta interfaz.
abstract interface class TestOutcomeRecognition {
  /// [recognitionClass] null = "No reconocido".
  void setTestOutcome(String? recognitionClass);
}
