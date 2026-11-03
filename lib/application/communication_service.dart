import 'dart:typed_data';

import '../domain/communication.dart';

class Board {
  final List<PictogramCategory> categories;
  final Map<int, List<Pictogram>> byCategory;

  const Board({required this.categories, required this.byCategory});

  bool get isEmpty => byCategory.values.every((l) => l.isEmpty);
  int get pictogramCount =>
      byCategory.values.fold(0, (sum, l) => sum + l.length);
}

class CommunicationService {
  CommunicationService(this._pictos);
  final PictogramRepository _pictos;

  Future<List<PictogramCategory>> categories() async =>
      (await _pictos.categories())
          .where((c) => c.availability == Availability.available)
          .toList();

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

  Future<List<ProfilePictogram>> catalog(int profileId) =>
      _pictos.catalogForProfile(profileId);

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
      if (categoryId == null) {
        throw const DomainException('Selecciona una categoría.');
      }
      updated = current.copyWith(categoryId: categoryId);
    }
    await _pictos.update(updated);
  }

  Future<void> setSelected(int profileId, int pictogramId, bool selected) =>
      _pictos.setSelected(profileId, pictogramId, selected);

  Future<void> reorder(int profileId, List<int> orderedIds) =>
      _pictos.reorder(profileId, orderedIds);

  Future<bool> deleteCustom(int pictogramId) =>
      _pictos.deleteCustomIfUnused(pictogramId);
}
