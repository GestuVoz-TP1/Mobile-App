library;

import 'dart:convert';

import 'shared.dart';

export 'shared.dart' show DomainException;

class Child {
  final int? id;
  final String name;
  final DateTime birthDate;
  final String? gender;

  const Child({
    this.id,
    required this.name,
    required this.birthDate,
    this.gender,
  });

  factory Child.create({
    int? id,
    required String name,
    required DateTime? birthDate,
    String? gender,
    DateTime? now,
  }) {
    if (name.trim().isEmpty) {
      throw const DomainException('El nombre del niño es obligatorio.');
    }
    if (birthDate == null) {
      throw const DomainException('La fecha de nacimiento es obligatoria.');
    }
    final age = ageAt(birthDate, now ?? DateTime.now());
    if (age < 2 || age > 17) {
      throw const DomainException('La edad debe estar entre 2 y 17 años.');
    }
    return Child(
      id: id,
      name: name.trim(),
      birthDate: DateTime(birthDate.year, birthDate.month, birthDate.day),
      gender: (gender == null || gender.trim().isEmpty) ? null : gender.trim(),
    );
  }

  int get age => ageAt(birthDate, DateTime.now());

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters1;
    final second = parts.length > 1 ? parts[1].characters1 : '';
    return (first + second).toUpperCase();
  }

  static int ageAt(DateTime birth, DateTime now) {
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }
}

extension on String {
  String get characters1 => isEmpty ? '' : String.fromCharCode(runes.first);
}

const kGenderOptions = ['Femenino', 'Masculino', 'Prefiero no indicar'];

const kPictogramSizeOptions = <int, String>{
  2: 'Grande',
  3: 'Mediano',
  4: 'Pequeño',
};

class CommunicationPreferences {
  final bool gesturesEnabled;

  final List<int> enabledGestureIds;

  final int pictogramColumns;

  final bool highContrast;

  const CommunicationPreferences({
    this.gesturesEnabled = false,
    this.enabledGestureIds = const [],
    this.pictogramColumns = 3,
    this.highContrast = false,
  });

  CommunicationPreferences copyWith({
    bool? gesturesEnabled,
    List<int>? enabledGestureIds,
    int? pictogramColumns,
    bool? highContrast,
  }) {
    final cols = pictogramColumns ?? this.pictogramColumns;
    if (!kPictogramSizeOptions.containsKey(cols)) {
      throw const DomainException('Selecciona un tamaño disponible.');
    }
    return CommunicationPreferences(
      gesturesEnabled: gesturesEnabled ?? this.gesturesEnabled,
      enabledGestureIds: enabledGestureIds ?? this.enabledGestureIds,
      pictogramColumns: cols,
      highContrast: highContrast ?? this.highContrast,
    );
  }

  String toJson() => jsonEncode({
        'gestos_activados': gesturesEnabled,
        'gestos_habilitados': enabledGestureIds,
        'columnas_tablero': pictogramColumns,
        'alto_contraste': highContrast,
      });

  factory CommunicationPreferences.fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return const CommunicationPreferences();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final cols = j['columnas_tablero'] as int? ?? 3;
      return CommunicationPreferences(
        gesturesEnabled: j['gestos_activados'] as bool? ?? false,
        enabledGestureIds: ((j['gestos_habilitados'] as List?) ?? const [])
            .whereType<int>()
            .toList(),
        pictogramColumns: kPictogramSizeOptions.containsKey(cols) ? cols : 3,
        highContrast: j['alto_contraste'] as bool? ?? false,
      );
    } catch (_) {
      return const CommunicationPreferences();
    }
  }
}

abstract final class ProfileState {
  static const active = 'activo';
}

class ChildProfile {
  final int? id;
  final int tutorId;
  final Child child;
  final String? supportLevel;
  final CommunicationPreferences preferences;
  final String state;

  const ChildProfile({
    this.id,
    required this.tutorId,
    required this.child,
    this.supportLevel,
    this.preferences = const CommunicationPreferences(),
    this.state = ProfileState.active,
  });

  ChildProfile copyWith({
    int? id,
    Child? child,
    String? supportLevel,
    CommunicationPreferences? preferences,
  }) =>
      ChildProfile(
        id: id ?? this.id,
        tutorId: tutorId,
        child: child ?? this.child,
        supportLevel: supportLevel ?? this.supportLevel,
        preferences: preferences ?? this.preferences,
        state: state,
      );
}

abstract interface class ChildProfileRepository {
  Future<List<ChildProfile>> forTutor(int tutorId);
  Future<ChildProfile?> byId(int profileId);

  Future<ChildProfile> create(ChildProfile profile);
  Future<void> update(ChildProfile profile);

  Future<void> delete(int profileId);
}
