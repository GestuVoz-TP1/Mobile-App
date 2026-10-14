import '../../domain/ml.dart';

/// Estructura preparada para el modelo real (OB2, secciones 8.1-8.3):
/// MobileNet (caracteristicas espaciales por fotograma) + LSTM (dependencia
/// temporal), exportado a `.tflite` y ejecutado en el dispositivo.
///
/// ESTADO: NO IMPLEMENTADO. Todavia no existe el archivo `.tflite` entrenado,
/// por lo que esta clase no esta registrada en `di.dart` y la app usa
/// [TestModeGestureRecognitionService].
///
/// Pasos para activarla en una etapa posterior:
///   1. Agregar la dependencia `tflite_flutter` y el modelo en
///      `assets/models/gestos.tflite` (declararlo en pubspec.yaml).
///   2. `load()`: crear el `Interpreter` desde el asset y leer la forma de
///      entrada [1, frames, alto, ancho, 3].
///   3. `recognize()`: redimensionar y normalizar cada fotograma de
///      [GestureSequence] (en memoria), ejecutar la inferencia, aplicar
///      softmax, tomar la clase con mayor probabilidad y devolverla solo si
///      supera [minConfidence] y esta en `candidateClasses`; si no, devolver
///      `GestureRecognitionResult.notRecognized()` (HU001 / HU006, criterio 2).
///   4. Registrar `RecognizerInfo(isRealModel: true)` y la latencia
///      (objetivo OB2: <= 200 ms).
///   5. En `di.dart`, reemplazar `TestModeGestureRecognitionService()` por esta
///      clase. Las clases de GESTO.clase_reconocimiento deben coincidir con
///      las etiquetas del modelo.
class TensorFlowLiteGestureRecognitionService
    implements GestureRecognitionService {
  TensorFlowLiteGestureRecognitionService({
    this.modelAsset = 'assets/models/gestos.tflite',
    this.minConfidence = 0.85,
  });

  final String modelAsset;

  /// Umbral para no comunicar un mensaje incorrecto (HU006, criterio 2).
  final double minConfidence;

  @override
  RecognizerInfo get info => const RecognizerInfo(
        name: 'MobileNet + LSTM (TensorFlow Lite)',
        isRealModel: true,
      );

  @override
  bool get isLoaded => false;

  @override
  Future<void> load() => throw UnimplementedError(
      'El modelo TensorFlow Lite aún no está disponible.');

  @override
  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  }) =>
      throw UnimplementedError(
          'El modelo TensorFlow Lite aún no está disponible.');

  @override
  Future<void> dispose() async {}
}
