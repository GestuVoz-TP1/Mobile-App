import '../domain/communication.dart';
import '../domain/consent.dart';
import '../domain/gesture.dart';
import '../domain/interaction.dart';

/// Servicio de aplicacion: registro de interacciones (RF-13).
///
/// D4: solo registra si el perfil tiene un consentimiento vigente.
class InteractionService {
  InteractionService(this._interactions, this._consents);
  final InteractionRepository _interactions;
  final ConsentRepository _consents;

  /// Registra la seleccion de un pictograma del tablero (HU008).
  Future<bool> recordPictogram(int profileId, Pictogram p) => _record(
        Interaction(
          at: DateTime.now(),
          detail: 'Pictograma seleccionado en el tablero',
          profileId: profileId,
          pictogramId: p.id!,
        ),
      );

  /// Registra un gesto reconocido (HU006).
  Future<bool> recordGesture(
    int profileId, {
    required Gesture gesture,
    required CommunicativeIntention intention,
    required Pictogram pictogram,
    required bool simulated,
  }) =>
      _record(
        Interaction(
          at: DateTime.now(),
          detail: simulated
              ? 'Gesto reconocido (DEMO — resultado simulado)'
              : 'Gesto reconocido',
          profileId: profileId,
          pictogramId: pictogram.id!,
          gestureId: gesture.id,
          intentionId: intention.id,
        ),
      );

  Future<bool> _record(Interaction i) async {
    final consent = await _consents.forProfile(i.profileId);
    if (!(consent?.allowsProcessing ?? false)) return false;
    await _interactions.add(i);
    return true;
  }
}
