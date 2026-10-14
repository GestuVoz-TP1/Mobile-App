import '../../domain/ml.dart';

/// Reconocedor que se usa mientras no existe el modelo entrenado.
///
/// NO es un modelo de Machine Learning y NO analiza las imagenes. Recibe la
/// secuencia capturada por la camara (para ejercitar el flujo real) y devuelve
/// el resultado elegido en el modo de prueba, que solo aparece en
/// compilaciones de desarrollo. Sin un resultado elegido devuelve
/// "no reconocido". Nunca informa porcentajes de confianza.
///
/// Se reemplazara por [TensorFlowLiteGestureRecognitionService] cuando exista
/// el modelo MobileNet + LSTM entrenado (OB2, seccion 8).
class TestModeGestureRecognitionService
    implements GestureRecognitionService, TestOutcomeRecognition {
  bool _loaded = false;
  String? _nextOutcome;

  @override
  RecognizerInfo get info => const RecognizerInfo(
        name: 'Reconocedor de prueba',
        isRealModel: false,
        notes: 'No existe todavía el modelo TensorFlow Lite entrenado.',
      );

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async => _loaded = true;

  @override
  void setTestOutcome(String? recognitionClass) =>
      _nextOutcome = recognitionClass;

  @override
  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  }) async {
    final outcome = _nextOutcome;
    _nextOutcome = null;
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
