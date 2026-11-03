import '../domain/communication.dart';
import '../domain/consent.dart';
import '../domain/gesture.dart';
import '../domain/interaction.dart';

class InteractionService {
  InteractionService(this._interactions, this._consents);
  final InteractionRepository _interactions;
  final ConsentRepository _consents;

  Future<bool> recordPictogram(int profileId, Pictogram p) => _record(
        Interaction(
          at: DateTime.now(),
          detail: 'Pictograma seleccionado en el tablero',
          profileId: profileId,
          pictogramId: p.id!,
        ),
      );

  Future<bool> recordGesture(
    int profileId, {
    required Gesture gesture,
    required CommunicativeIntention intention,
    required Pictogram pictogram,
  }) =>
      _record(
        Interaction(
          at: DateTime.now(),
          detail: 'Gesto reconocido',
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
