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

class GestureCustomization {
  final String? message;
  final int? pictogramId;

  const GestureCustomization({this.message, this.pictogramId});

  bool get isEmpty => message == null && pictogramId == null;
}

const kSupportLevelOptions = [
  'Nivel 1: necesita apoyo',
  'Nivel 2: necesita apoyo sustancial',
  'Nivel 3: necesita apoyo muy sustancial',
];

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

  final Map<int, int> pictogramCategories;

  final Map<int, GestureCustomization> gestureCustomizations;

  const CommunicationPreferences({
    this.gesturesEnabled = false,
    this.enabledGestureIds = const [],
    this.pictogramColumns = 3,
    this.highContrast = false,
    this.pictogramCategories = const {},
    this.gestureCustomizations = const {},
  });

  CommunicationPreferences copyWith({
    bool? gesturesEnabled,
    List<int>? enabledGestureIds,
    int? pictogramColumns,
    bool? highContrast,
    Map<int, int>? pictogramCategories,
    Map<int, GestureCustomization>? gestureCustomizations,
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
      pictogramCategories: pictogramCategories ?? this.pictogramCategories,
      gestureCustomizations:
          gestureCustomizations ?? this.gestureCustomizations,
    );
  }

  String toJson() => jsonEncode({
        'gestos_activados': gesturesEnabled,
        'gestos_habilitados': enabledGestureIds,
        'columnas_tablero': pictogramColumns,
        'alto_contraste': highContrast,
        'categorias_pictogramas': {
          for (final e in pictogramCategories.entries)
            e.key.toString(): e.value,
        },
        'gestos_personalizados': {
          for (final e in gestureCustomizations.entries)
            e.key.toString(): {
              'mensaje': e.value.message,
              'id_pictograma': e.value.pictogramId,
            },
        },
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
        pictogramCategories: {
          for (final e in ((j['categorias_pictogramas'] as Map?) ?? const {})
              .entries)
            if (int.tryParse('${e.key}') != null && e.value is int)
              int.parse('${e.key}'): e.value as int,
        },
        gestureCustomizations: {
          for (final e in ((j['gestos_personalizados'] as Map?) ?? const {})
              .entries)
            if (int.tryParse('${e.key}') != null && e.value is Map)
              int.parse('${e.key}'): GestureCustomization(
                message: (e.value as Map)['mensaje'] as String?,
                pictogramId: (e.value as Map)['id_pictograma'] as int?,
              ),
        },
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
