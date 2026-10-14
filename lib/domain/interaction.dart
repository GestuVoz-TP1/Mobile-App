/// -------------------------------------------------------------------------
/// Bounded context: INTERACCION (registro de uso)
///
/// Cada mensaje comunicado por el nino (pictograma tocado o gesto reconocido)
/// se registra en INTERACCION (RF-13). Solo se registra si el perfil tiene un
/// consentimiento vigente (D4).
/// -------------------------------------------------------------------------
library;

/// Recurso de comunicacion utilizado (se deduce de las FK).
enum InteractionSource { pictogram, gesture }

extension InteractionSourceX on InteractionSource {
  String get label => switch (this) {
        InteractionSource.pictogram => 'Pictograma',
        InteractionSource.gesture => 'Gesto',
      };
}

/// INTERACCION
class Interaction {
  final int? id;
  final DateTime at;
  final String? detail;
  final int profileId;
  final int pictogramId;

  /// Solo en interacciones por gesto (FK opcionales, ver TRAZABILIDAD.md).
  final int? gestureId;
  final int? intentionId;

  const Interaction({
    this.id,
    required this.at,
    this.detail,
    required this.profileId,
    required this.pictogramId,
    this.gestureId,
    this.intentionId,
  });

  InteractionSource get source =>
      gestureId != null ? InteractionSource.gesture : InteractionSource.pictogram;
}

/// Fila del historial con los nombres ya resueltos (para mostrar).
class InteractionRecord {
  final Interaction interaction;
  final String pictogramName;
  final String pictogramMessage;
  final String? pictogramEmoji;
  final bool pictogramHasImage;
  final int categoryId;
  final String? gestureName;
  final String? intentionName;

  const InteractionRecord({
    required this.interaction,
    required this.pictogramName,
    required this.pictogramMessage,
    this.pictogramEmoji,
    required this.pictogramHasImage,
    required this.categoryId,
    this.gestureName,
    this.intentionName,
  });
}

abstract interface class InteractionRepository {
  Future<Interaction> add(Interaction interaction);

  /// Historial del perfil (mas reciente primero), opcionalmente filtrado por
  /// rango de fechas [from, to) (HU032).
  Future<List<InteractionRecord>> recordsForProfile(
    int profileId, {
    DateTime? from,
    DateTime? to,
  });

  Future<InteractionRecord?> recordById(int id);
}
