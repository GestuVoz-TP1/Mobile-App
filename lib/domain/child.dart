/// -------------------------------------------------------------------------
/// Bounded context: NINO / PERFIL DEL NINO
///
/// NINO guarda los datos basicos del nino y PERFIL_NINO su configuracion
/// comunicativa. Relacion NINO 1:1 PERFIL_NINO y PADRE_TUTOR 1:N PERFIL_NINO
/// (OB2, 5.2): un tutor administra uno o varios perfiles (HU021).
/// -------------------------------------------------------------------------
library;

import 'dart:convert';

import 'shared.dart';

export 'shared.dart' show DomainException;

/// NINO
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

  /// Valida los datos obligatorios (HU021 / HU022, criterio 2).
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

  /// Iniciales para el avatar (D6: el modelo no contempla avatar).
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

/// Opciones de genero ofrecidas en el formulario (NINO.genero es opcional).
const kGenderOptions = ['Femenino', 'Masculino', 'Prefiero no indicar'];

/// Opciones de tamano de pictogramas (HU016): columnas del tablero.
/// Menos columnas = pictogramas mas grandes.
const kPictogramSizeOptions = <int, String>{
  2: 'Grande',
  3: 'Mediano',
  4: 'Pequeño',
};

/// Contenido de PERFIL_NINO.preferencias_comunicacion (JSON).
class CommunicationPreferences {
  /// HU004: modalidad de gestos activada para el perfil.
  final bool gesturesEnabled;

  /// RF-15: gestos habilitados para el perfil (ids de GESTO).
  final List<int> enabledGestureIds;

  /// HU016: columnas del tablero (2 grande, 3 mediano, 4 pequeno).
  final int pictogramColumns;

  /// RNF-04 / WCAG 2.1 AA: alto contraste.
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

/// PERFIL_NINO.estado_perfil
abstract final class ProfileState {
  static const active = 'activo';
}

/// PERFIL_NINO
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

  /// Crea NINO + PERFIL_NINO + datos iniciales del perfil (configuracion de
  /// voz y pictogramas semilla seleccionados, D9) en una sola transaccion.
  Future<ChildProfile> create(ChildProfile profile);
  Future<void> update(ChildProfile profile);

  /// D5: borra en cascada los datos exclusivos del perfil.
  Future<void> delete(int profileId);
}
