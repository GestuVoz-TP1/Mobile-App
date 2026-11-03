import '../domain/child.dart';
import '../domain/communication.dart';
import '../domain/gesture.dart';
import '../domain/ml.dart';

class GestureMessage {
  final Gesture gesture;
  final String originalMessage;
  final String message;
  final Pictogram? originalPictogram;
  final Pictogram? pictogram;

  const GestureMessage({
    required this.gesture,
    required this.originalMessage,
    required this.message,
    required this.originalPictogram,
    required this.pictogram,
  });

  bool get isCustomized =>
      message != originalMessage || pictogram?.id != originalPictogram?.id;
}

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

class GestureService {
  GestureService(this._recognizer, this._gestures, this._pictos);
  final GestureRecognitionService _recognizer;
  final GestureRepository _gestures;
  final PictogramRepository _pictos;

  RecognizerInfo get recognizerInfo => _recognizer.info;

  bool get supportsTestOutcome => _recognizer is TestOutcomeRecognition;

  Future<void> ensureLoaded() async {
    if (!_recognizer.isLoaded) await _recognizer.load();
  }

  Future<List<Gesture>> catalog() => _gestures.all();

  Future<CommunicativeIntention?> intentionFor(Gesture g) =>
      _gestures.intentionForGesture(g.id);

  Future<List<Gesture>> enabledFor(ChildProfile profile) async {
    final ids = profile.preferences.enabledGestureIds.toSet();
    return (await _gestures.all())
        .where((g) =>
            ids.contains(g.id) && g.availability == Availability.available)
        .toList();
  }

  Future<GestureMessage?> messageFor(int profileId, Gesture g) async {
    final intention = await _gestures.intentionForGesture(g.id);
    if (intention == null) return null;
    final original = await _pictos.byIntention(intention.id);
    final custom = await _gestures.customizationFor(profileId, g.id);
    final customPicto = custom?.pictogramId == null
        ? null
        : await _pictos.byId(custom!.pictogramId!);
    return GestureMessage(
      gesture: g,
      originalMessage: intention.message,
      message: custom?.message ?? intention.message,
      originalPictogram: original,
      pictogram: customPicto ?? original,
    );
  }

  Future<void> saveMessage(
    int profileId,
    Gesture g, {
    required String message,
    required int? pictogramId,
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw const DomainException('Escribe el mensaje del gesto.');
    }
    final current = await messageFor(profileId, g);
    await _gestures.setCustomization(
      profileId,
      g.id,
      GestureCustomization(
        message: text == current?.originalMessage ? null : text,
        pictogramId:
            pictogramId == current?.originalPictogram?.id ? null : pictogramId,
      ),
    );
  }

  Future<void> resetMessage(int profileId, Gesture g) =>
      _gestures.setCustomization(profileId, g.id, null);

  Future<void> updateInstructions(int gestureId, String? text) =>
      _gestures.updateInstructions(gestureId, text);

  void setTestOutcome(String? recognitionClass) {
    final r = _recognizer;
    if (r is TestOutcomeRecognition) {
      (r as TestOutcomeRecognition).setTestOutcome(recognitionClass);
    }
  }

  bool get supportsContinuous => _recognizer is ContinuousGestureRecognition;

  void resetContinuous() {
    final r = _recognizer;
    if (r is ContinuousGestureRecognition) {
      (r as ContinuousGestureRecognition).reset();
    }
  }

  Future<GestureOutcome?> addFrame(
    GestureFrame frame,
    List<Gesture> enabled, {
    required int profileId,
  }) async {
    final r = _recognizer;
    if (r is! ContinuousGestureRecognition) return null;
    await ensureLoaded();
    final result = await (r as ContinuousGestureRecognition).addFrame(
      frame,
      candidateClasses: enabled.map((g) => g.recognitionClass).toList(),
    );
    if (result == null) return null;
    return _outcomeFor(result, enabled, profileId);
  }

  Future<GestureOutcome?> recognize(
    GestureSequence sequence,
    List<Gesture> enabled, {
    required int profileId,
  }) async {
    await ensureLoaded();
    final result = await _recognizer.recognize(
      sequence,
      candidateClasses: enabled.map((g) => g.recognitionClass).toList(),
    );
    return _outcomeFor(result, enabled, profileId);
  }

  Future<GestureOutcome?> _outcomeFor(
    GestureRecognitionResult result,
    List<Gesture> enabled,
    int profileId,
  ) async {
    if (!result.recognized) return null;
    final gesture = enabled
        .where((g) => g.recognitionClass == result.recognitionClass)
        .firstOrNull;
    if (gesture == null) return null;
    final intention = await _gestures.intentionForGesture(gesture.id);
    if (intention == null) return null;
    final chosen = await messageFor(profileId, gesture);
    final pictogram = chosen?.pictogram;
    if (chosen == null || pictogram == null) return null;
    return GestureOutcome(
      gesture: gesture,
      intention: CommunicativeIntention(
        id: intention.id,
        name: intention.name,
        description: intention.description,
        message: chosen.message,
        gestureId: intention.gestureId,
      ),
      pictogram: pictogram,
      result: result,
    );
  }
}
