library;

import 'child.dart' show GestureCustomization;

export 'shared.dart' show DomainException;

class Gesture {
  final int id;
  final String name;
  final String? description;

  final String? visualRepresentation;

  final String recognitionClass;
  final String availability;

  final String? instructions;

  const Gesture({
    required this.id,
    required this.name,
    this.description,
    this.visualRepresentation,
    required this.recognitionClass,
    required this.availability,
    this.instructions,
  });

  bool get hasInstructions =>
      instructions != null && instructions!.trim().isNotEmpty;

  List<String> get instructionSteps => (instructions ?? '')
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class CommunicativeIntention {
  final int id;
  final String name;
  final String? description;
  final String message;
  final int gestureId;

  const CommunicativeIntention({
    required this.id,
    required this.name,
    this.description,
    required this.message,
    required this.gestureId,
  });
}

abstract interface class GestureRepository {
  Future<List<Gesture>> all();
  Future<Gesture?> byId(int id);
  Future<Gesture?> byRecognitionClass(String recognitionClass);
  Future<CommunicativeIntention?> intentionForGesture(int gestureId);
  Future<CommunicativeIntention?> intentionById(int id);
  Future<void> updateInstructions(int gestureId, String? instructions);

  Future<GestureCustomization?> customizationFor(int profileId, int gestureId);

  Future<void> setCustomization(
      int profileId, int gestureId, GestureCustomization? customization);
}
