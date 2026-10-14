import '../domain/child.dart';
import '../domain/communication.dart';
import '../domain/gesture.dart';
import '../domain/ml.dart';

/// Resultado completo de un intento: gesto -> intencion -> pictograma.
class GestureOutcome {
  final Gesture gesture;
  final CommunicativeIntention intention;
  final Pictogram pictogram;
  final GestureRecognitionResult result;

  const GestureOutcome({
    required this.gesture,
    required this.intention,
    required this.pictogram,
    required this.result,
  });
}

/// Servicio de aplicacion: comunicacion mediante gestos (E1).
///
/// Camara -> [GestureRecognitionService] -> GESTO -> INTENCION_COMUNICATIVA
/// -> PICTOGRAMA. La voz y el registro los coordina el controlador.
class GestureService {
  GestureService(this._recognizer, this._gestures, this._pictos);
  final GestureRecognitionService _recognizer;
  final GestureRepository _gestures;
  final PictogramRepository _pictos;

  RecognizerInfo get recognizerInfo => _recognizer.info;

  /// true si el reconocedor actual es DEMO (resultado simulado).
  bool get isSimulated => _recognizer is SimulatedGestureRecognition;

  Future<void> ensureLoaded() async {
    if (!_recognizer.isLoaded) await _recognizer.load();
  }

  /// HU003: catalogo de gestos definidos.
  Future<List<Gesture>> catalog() => _gestures.all();

  Future<CommunicativeIntention?> intentionFor(Gesture g) =>
      _gestures.intentionForGesture(g.id);

  /// Gestos habilitados para el perfil (RF-15) y disponibles.
  Future<List<Gesture>> enabledFor(ChildProfile profile) async {
    final ids = profile.preferences.enabledGestureIds.toSet();
    return (await _gestures.all())
        .where((g) =>
            ids.contains(g.id) && g.availability == Availability.available)
        .toList();
  }

  /// Instrucciones editables (D10).
  Future<void> updateInstructions(int gestureId, String? text) =>
      _gestures.updateInstructions(gestureId, text);

  /// Solo para el reconocedor DEMO: fija el resultado del siguiente intento.
  void setSimulatedOutcome(String? recognitionClass) {
    final r = _recognizer;
    if (r is SimulatedGestureRecognition) {
      (r as SimulatedGestureRecognition).setSimulatedOutcome(recognitionClass);
    }
  }

  /// HU001 / HU006: devuelve null si el gesto no se reconoce o no puede
  /// asociarse a un mensaje (no se comunica un mensaje incorrecto).
  Future<GestureOutcome?> recognize(
    GestureSequence sequence,
    List<Gesture> enabled,
  ) async {
    await ensureLoaded();
    final result = await _recognizer.recognize(
      sequence,
      candidateClasses: enabled.map((g) => g.recognitionClass).toList(),
    );
    if (!result.recognized) return null;
    final gesture = enabled
        .where((g) => g.recognitionClass == result.recognitionClass)
        .firstOrNull;
    if (gesture == null) return null;
    final intention = await _gestures.intentionForGesture(gesture.id);
    if (intention == null) return null;
    final pictogram = await _pictos.byIntention(intention.id);
    if (pictogram == null) return null;
    return GestureOutcome(
      gesture: gesture,
      intention: intention,
      pictogram: pictogram,
      result: result,
    );
  }
}
