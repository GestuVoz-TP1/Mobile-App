import '../../domain/ml.dart';

/// Reconocedor DEMO.
///
/// NO es un modelo de Machine Learning y NO analiza las imagenes. Recibe la
/// secuencia capturada por la camara (para ejercitar el flujo real) y devuelve
/// el resultado que elige quien prueba la app en el selector
/// "DEMO — resultado simulado" (D7). Nunca informa porcentajes de confianza.
///
/// Se reemplazara por [TensorFlowLiteGestureRecognitionService] cuando exista
/// el modelo MobileNet + LSTM entrenado (OB2, seccion 8).
class MockGestureRecognitionService
    implements GestureRecognitionService, SimulatedGestureRecognition {
  bool _loaded = false;
  String? _nextOutcome;
  bool _outcomeSet = false;

  @override
  RecognizerInfo get info => const RecognizerInfo(
        name: 'Reconocimiento simulado (DEMO)',
        isRealModel: false,
        notes: 'No existe todavía el modelo TensorFlow Lite entrenado. '
            'El resultado lo selecciona quien prueba la aplicación.',
      );

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async => _loaded = true;

  @override
  void setSimulatedOutcome(String? recognitionClass) {
    _nextOutcome = recognitionClass;
    _outcomeSet = true;
  }

  @override
  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  }) async {
    final outcome = _outcomeSet ? _nextOutcome : null;
    _nextOutcome = null;
    _outcomeSet = false;
    if (sequence.isEmpty ||
        outcome == null ||
        !candidateClasses.contains(outcome)) {
      return const GestureRecognitionResult.notRecognized();
    }
    return GestureRecognitionResult(recognitionClass: outcome);
  }

  @override
  Future<void> dispose() async => _loaded = false;
}
