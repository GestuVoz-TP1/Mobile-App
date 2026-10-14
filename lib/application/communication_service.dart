import 'dart:typed_data';

import '../domain/communication.dart';

/// Tablero listo para pintar: categorias -> pictogramas del perfil, en el
/// orden que definio el tutor (HU007, HU010, HU015).
class Board {
  final List<PictogramCategory> categories;
  final Map<int, List<Pictogram>> byCategory;

  const Board({required this.categories, required this.byCategory});

  bool get isEmpty => byCategory.values.every((l) => l.isEmpty);
  int get pictogramCount =>
      byCategory.values.fold(0, (sum, l) => sum + l.length);
}

/// Servicio de aplicacion del contexto de comunicacion (E2, E3).
class CommunicationService {
  CommunicationService(this._pictos);
  final PictogramRepository _pictos;

  Future<List<PictogramCategory>> categories() async =>
      (await _pictos.categories())
          .where((c) => c.availability == Availability.available)
          .toList();

  /// HU007: pictogramas disponibles para el perfil, agrupados por categoria.
  Future<Board> buildBoard(int profileId) async {
    final cats = await categories();
    final board = await _pictos.boardForProfile(profileId);
    return Board(
      categories: cats,
      byCategory: {
        for (final c in cats)
          c.id: board.where((p) => p.categoryId == c.id).toList(),
      },
    );
  }

  Future<Pictogram?> byId(int id) => _pictos.byId(id);
  Future<Pictogram?> byIntention(int intentionId) =>
      _pictos.byIntention(intentionId);

  // --- Gestion del tutor (E3) ----------------------------------------------

  Future<List<ProfilePictogram>> catalog(int profileId) =>
      _pictos.catalogForProfile(profileId);

  /// HU012: imagen y mensaje obligatorios; queda disponible en el tablero.
  Future<Pictogram> addCustom({
    required int profileId,
    required String name,
    required String message,
    required int? categoryId,
    required Uint8List? image,
  }) =>
      _pictos.insertCustom(
        Pictogram.custom(
            name: name, message: message, categoryId: categoryId, image: image),
        profileId,
      );

  /// HU013 (imagen/mensaje) y HU014 (categoria).
  Future<void> updatePictogram(
    Pictogram current, {
    required String name,
    required String message,
    required int? categoryId,
    Uint8List? image,
  }) async {
    final Pictogram updated;
    if (current.isCustom) {
      updated = Pictogram.custom(
        id: current.id,
        name: name,
        message: message,
        categoryId: categoryId,
        image: image ?? current.image,
      );
    } else {
      // Pictograma semilla: solo se permite cambiar su categoria (HU014).
      if (categoryId == null) {
        throw const DomainException('Selecciona una categoría.');
      }
      updated = current.copyWith(categoryId: categoryId);
    }
    await _pictos.update(updated);
  }

  /// HU015: mostrar u ocultar en el tablero sin eliminar del catalogo.
  Future<void> setSelected(int profileId, int pictogramId, bool selected) =>
      _pictos.setSelected(profileId, pictogramId, selected);

  Future<void> reorder(int profileId, List<int> orderedIds) =>
      _pictos.reorder(profileId, orderedIds);

  /// Elimina un pictograma personalizado si no tiene historial.
  Future<bool> deleteCustom(int pictogramId) =>
      _pictos.deleteCustomIfUnused(pictogramId);
}
