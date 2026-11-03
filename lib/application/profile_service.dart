import '../domain/child.dart';
import '../domain/gesture.dart';

/// Datos del formulario de perfil infantil.
class ProfileForm {
  final String name;
  final DateTime? birthDate;
  final String? gender;
  final String? supportLevel;

  const ProfileForm({
    required this.name,
    required this.birthDate,
    this.gender,
    this.supportLevel,
  });
}

/// Perfiles infantiles del tutor y sus preferencias de comunicacion.
class ProfileService {
  ProfileService(this._profiles, this._gestures);
  final ChildProfileRepository _profiles;
  final GestureRepository _gestures;

  Future<List<ChildProfile>> forTutor(int tutorId) =>
      _profiles.forTutor(tutorId);

  Future<ChildProfile?> byId(int id) => _profiles.byId(id);

  /// Lanza [DomainException] si faltan datos obligatorios.
  Future<ChildProfile> create(int tutorId, ProfileForm f) async {
    final child = Child.create(
        name: f.name, birthDate: f.birthDate, gender: f.gender);
    final gestures = await _gestures.all();
    return _profiles.create(ChildProfile(
      tutorId: tutorId,
      child: child,
      supportLevel: _clean(f.supportLevel),
      // Por defecto se habilitan los gestos disponibles; la modalidad queda
      // desactivada hasta que el tutor la prepare.
      preferences: CommunicationPreferences(
        enabledGestureIds: gestures.map((g) => g.id).toList(),
      ),
    ));
  }

  /// Actualiza solo ese perfil.
  Future<ChildProfile> update(ChildProfile current, ProfileForm f) async {
    final child = Child.create(
      id: current.child.id,
      name: f.name,
      birthDate: f.birthDate,
      gender: f.gender,
    );
    final updated = ChildProfile(
      id: current.id,
      tutorId: current.tutorId,
      child: child,
      supportLevel: _clean(f.supportLevel),
      preferences: current.preferences,
      state: current.state,
    );
    await _profiles.update(updated);
    return updated;
  }

  Future<ChildProfile> savePreferences(
      ChildProfile current, CommunicationPreferences prefs) async {
    final updated = current.copyWith(preferences: prefs);
    await _profiles.update(updated);
    return updated;
  }

  Future<void> delete(int profileId) => _profiles.delete(profileId);

  static String? _clean(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
