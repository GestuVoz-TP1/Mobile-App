library;

/// Decision of the guardian about the processing of the data of a child.
enum ConsentState { granted, notGranted, withdrawn }

extension ConsentStateX on ConsentState {
  String get dbValue => switch (this) {
        ConsentState.granted => 'otorgado',
        ConsentState.notGranted => 'no_otorgado',
        ConsentState.withdrawn => 'retirado',
      };

  String get label => switch (this) {
        ConsentState.granted => 'Otorgado',
        ConsentState.notGranted => 'No otorgado',
        ConsentState.withdrawn => 'Retirado',
      };

  static ConsentState fromDb(String? v) => switch (v) {
        'otorgado' => ConsentState.granted,
        'retirado' => ConsentState.withdrawn,
        _ => ConsentState.notGranted,
      };
}

/// Consent registered for one child profile.
class Consent {
  final int? id;
  final int profileId;
  final ConsentState state;
  final DateTime registeredAt;
  final DateTime? withdrawnAt;

  const Consent({
    this.id,
    required this.profileId,
    required this.state,
    required this.registeredAt,
    this.withdrawnAt,
  });

  bool get allowsProcessing => state == ConsentState.granted;
}

/// Persistence of the consent of each profile.
abstract interface class ConsentRepository {
  Future<Consent?> forProfile(int profileId);
  Future<Consent> save(Consent consent);
}
