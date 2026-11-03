library;

enum InteractionSource { pictogram, gesture }

extension InteractionSourceX on InteractionSource {
  String get label => switch (this) {
        InteractionSource.pictogram => 'Pictograma',
        InteractionSource.gesture => 'Gesto',
      };
}

class Interaction {
  final int? id;
  final DateTime at;
  final String? detail;
  final int profileId;
  final int pictogramId;

  final int? gestureId;
  final int? intentionId;

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

  Future<List<InteractionRecord>> recordsForProfile(
    int profileId, {
    DateTime? from,
    DateTime? to,
  });

  Future<InteractionRecord?> recordById(int id);
}
