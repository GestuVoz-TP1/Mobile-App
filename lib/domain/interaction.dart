/// Cada mensaje comunicado por el nino (pictograma tocado o gesto reconocido)
/// se registra en INTERACCION. Solo se registra si el perfil tiene un
/// consentimiento vigente.
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

  /// Solo en interacciones por gesto (FK opcionales: una interaccion por
  /// pictograma no tiene gesto).
  final int? gestureId;
  final int? intentionId;

  /// Identificador en el backend (documento de `interacciones`).
  final String? remoteId;

  const Interaction({
    this.id,
    this.remoteId,
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

  /// Antes de guardar la frase, `detalle` tenia estos textos fijos.
  static const _legacyDetails = {
    'Gesto reconocido',
    'Pictograma seleccionado en el tablero',
  };

  /// Lo que se comunico: la frase guardada en ese momento, para que cambiar
  /// despues un mensaje no reescriba el historial. Los registros anteriores
  /// no la tienen y muestran el mensaje actual del pictograma.
  String get message {
    final detail = interaction.detail;
    return detail == null || _legacyDetails.contains(detail)
        ? pictogramMessage
        : detail;
  }
}

abstract interface class InteractionRepository {
  Future<Interaction> add(Interaction interaction);

  /// Historial del perfil (mas reciente primero), opcionalmente filtrado por
  /// rango de fechas [from, to).
  Future<List<InteractionRecord>> recordsForProfile(
    int profileId, {
    DateTime? from,
    DateTime? to,
  });

  Future<InteractionRecord?> recordById(int id);
}
