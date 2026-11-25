import '../domain/communication.dart';
import '../domain/consent.dart';
import '../domain/gesture.dart';
import '../domain/interaction.dart';

/// Registers the interactions of the child in the history.
class InteractionService {
  InteractionService(this._interactions, this._consents);
  final InteractionRepository _interactions;
  final ConsentRepository _consents;

  Future<bool> recordPictogram(int profileId, Pictogram p) => _record(
        Interaction(
          at: DateTime.now(),
          detail: p.message,
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
          detail: intention.message,
          profileId: profileId,
          pictogramId: pictogram.id!,
          gestureId: gesture.id,
          intentionId: intention.id,
        ),
      );

  /// Stores [i] only when the profile has a valid consent, as required by
  /// Law 29733. Returns whether the interaction was stored.
  Future<bool> _record(Interaction i) async {
    final consent = await _consents.forProfile(i.profileId);
    if (!(consent?.allowsProcessing ?? false)) return false;
    await _interactions.add(i);
    return true;
  }
}
