library;

import 'dart:typed_data';

import 'shared.dart';

export 'shared.dart' show DomainException;

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

abstract final class Availability {
  static const available = 'disponible';
}

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

  bool get isCustom => hasImage;

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

class ProfilePictogram {
  final Pictogram pictogram;

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

  Future<List<ProfilePictogram>> catalogForProfile(int profileId);

  Future<List<Pictogram>> boardForProfile(int profileId);

  Future<Pictogram?> byId(int id);
  Future<Pictogram?> byIntention(int intentionId);

  Future<Pictogram> insertCustom(Pictogram pictogram, int profileId);
  Future<void> update(Pictogram pictogram);

  Future<void> setSelected(int profileId, int pictogramId, bool selected);

  Future<void> reorder(int profileId, List<int> orderedPictogramIds);

  Future<bool> deleteCustomIfUnused(int pictogramId);
}
