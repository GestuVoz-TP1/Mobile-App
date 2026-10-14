/// -------------------------------------------------------------------------
/// Bounded context: PRIVACIDAD (CONSENTIMIENTO)
///
/// Decision del padre o tutor sobre el tratamiento de los datos del nino
/// (Ley N.º 29733). PERFIL_NINO 1:1 CONSENTIMIENTO (OB2, 5.2). HU027-HU029.
/// -------------------------------------------------------------------------
library;

/// CONSENTIMIENTO.estado_consentimiento
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

  /// Solo con consentimiento vigente se registran interacciones y se
  /// habilita la camara de gestos.
  bool get allowsProcessing => state == ConsentState.granted;
}

abstract interface class ConsentRepository {
  /// null si el perfil aun no tiene una decision registrada.
  Future<Consent?> forProfile(int profileId);
  Future<Consent> save(Consent consent);
}
