/// -------------------------------------------------------------------------
/// Bounded context: GESTOS E INTENCIONES COMUNICATIVAS
///
/// GESTO 1:1 INTENCION_COMUNICATIVA 1:1 PICTOGRAMA (OB2, 5.2). El modelo de
/// reconocimiento devuelve una `clase_reconocimiento`; con ella se obtiene el
/// gesto, su intencion y el pictograma que la representa.
/// -------------------------------------------------------------------------
library;

export 'shared.dart' show DomainException;

/// GESTO
class Gesture {
  final int id;
  final String name;
  final String? description;

  /// Referencia visual del gesto (emoji o ruta de recurso).
  final String? visualRepresentation;

  /// Etiqueta que devuelve el modelo de reconocimiento.
  final String recognitionClass;
  final String availability;

  /// Indicaciones para realizar el gesto. Editables por el tutor; pueden
  /// estar vacias.
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

  /// Pasos de las instrucciones (una linea por paso).
  List<String> get instructionSteps => (instructions ?? '')
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// INTENCION_COMUNICATIVA
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
}
