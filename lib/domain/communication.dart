/// -------------------------------------------------------------------------
/// Bounded context: COMUNICACION
///
/// Catalogo de pictogramas (PICTOGRAMA), sus categorias (CATEGORIA) y la
/// seleccion/orden de pictogramas de cada perfil (PERFIL_PICTOGRAMA).
/// -------------------------------------------------------------------------
library;

import 'dart:typed_data';

import 'shared.dart';

export 'shared.dart' show DomainException;

/// CATEGORIA
class PictogramCategory {
  final int id;
  final String name;
  final String? description;
  final String availability;

  const PictogramCategory({
    required this.id,
    required this.name,
    this.description,
    this.availability = Availability.available,
  });
}

/// Valores de `estado_disponibilidad` (CATEGORIA, GESTO).
abstract final class Availability {
  static const available = 'disponible';
}

/// PICTOGRAMA. [message] es la frase que se reproduce por voz.
///
/// Un pictograma personalizado (HU012) siempre tiene [image]; los
/// pictogramas semilla se representan con [emoji] (D6).
class Pictogram {
  final int? id;
  final String name;
  final String message;
  final int categoryId;
  final Uint8List? image;
  final String? emoji;
  final int? intentionId;

  const Pictogram({
    this.id,
    required this.name,
    required this.message,
    required this.categoryId,
    this.image,
    this.emoji,
    this.intentionId,
  });

  bool get hasImage => image != null && image!.isNotEmpty;

  /// Personalizado = creado por el tutor con imagen propia.
  bool get isCustom => hasImage;

  /// Valida un pictograma personalizado (HU012 / HU013, criterio 2).
  factory Pictogram.custom({
    int? id,
    required String name,
    required String message,
    required int? categoryId,
    required Uint8List? image,
  }) {
    if (image == null || image.isEmpty) {
      throw const DomainException('Agrega una imagen para el pictograma.');
    }
    if (message.trim().isEmpty) {
      throw const DomainException('Escribe el mensaje que dirá la voz.');
    }
    if (categoryId == null) {
      throw const DomainException('Selecciona una categoría.');
    }
    final trimmedName = name.trim();
    return Pictogram(
      id: id,
      name: trimmedName.isEmpty ? message.trim() : trimmedName,
      message: message.trim(),
      categoryId: categoryId,
      image: image,
    );
  }

  Pictogram copyWith({
    String? name,
    String? message,
    int? categoryId,
    Uint8List? image,
  }) =>
      Pictogram(
        id: id,
        name: name ?? this.name,
        message: message ?? this.message,
        categoryId: categoryId ?? this.categoryId,
        image: image ?? this.image,
        emoji: emoji,
        intentionId: intentionId,
      );
}

/// Pictograma del catalogo junto con su estado para un perfil.
class ProfilePictogram {
  final Pictogram pictogram;

  /// true si tiene fila en PERFIL_PICTOGRAMA (visible en el tablero).
  final bool selected;
  final int? order;

  const ProfilePictogram({
    required this.pictogram,
    required this.selected,
    this.order,
  });
}

abstract interface class PictogramRepository {
  Future<List<PictogramCategory>> categories();

  /// Catalogo completo (PICTOGRAMA) con la seleccion del perfil.
  Future<List<ProfilePictogram>> catalogForProfile(int profileId);

  /// Pictogramas seleccionados del perfil, en su orden (tablero del nino).
  Future<List<Pictogram>> boardForProfile(int profileId);

  Future<Pictogram?> byId(int id);
  Future<Pictogram?> byIntention(int intentionId);

  /// Inserta un pictograma personalizado y lo selecciona para el perfil.
  Future<Pictogram> insertCustom(Pictogram pictogram, int profileId);
  Future<void> update(Pictogram pictogram);

  /// HU015: mostrar/ocultar sin eliminar del catalogo.
  Future<void> setSelected(int profileId, int pictogramId, bool selected);

  /// RF-07: orden del tablero del perfil.
  Future<void> reorder(int profileId, List<int> orderedPictogramIds);

  /// Elimina un pictograma personalizado si no tiene interacciones
  /// registradas. Devuelve false si no pudo eliminarse.
  Future<bool> deleteCustomIfUnused(int pictogramId);
}
