import '../../domain/ml.dart';

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
