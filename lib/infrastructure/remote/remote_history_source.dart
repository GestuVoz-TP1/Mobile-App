import '../../domain/auth.dart' show DomainException;
import '../../domain/interaction.dart';
import '../../domain/reporting.dart';
import '../persistence/database.dart';
import '../sync/sync_service.dart' show RemoteIds;
import 'api_client.dart';

/// Historial y reportes consultados al backend (OB2, "Generacion de
/// reportes"; E6, HU030-HU033).
///
/// Los identificadores remotos se traducen a los nombres guardados en el
/// telefono (pictogramas, gestos e intenciones).
class RemoteHistorySource implements HistorySource {
  RemoteHistorySource(this._db, this._api, {this.beforeQuery});

  final GestuVozDatabase _db;
  final ApiClient _api;

  /// Envia lo pendiente antes de consultar, para que el historial incluya
  /// lo registrado en el telefono.
  final Future<void> Function()? beforeQuery;

  static const offlineMessage =
      'Se necesita conexión a internet para consultar el historial.';

  @override
  Future<List<InteractionRecord>> records(int profileId,
      {DateTime? from, DateTime? to}) async {
    final data = await _query(profileId, 'interacciones', from, to);
    if (data == null) return const [];
    final names = await _Names.load(_db);
    return [
      for (final item in data as List<dynamic>)
        await _record(profileId, item as Map<String, dynamic>, names),
    ];
  }

  @override
  Future<UsageSummary> summary(int profileId,
      {DateTime? from, DateTime? to}) async {
    final data =
        await _query(profileId, 'reportes', from, to) as Map<String, dynamic>?;
    if (data == null) {
      return const UsageSummary(
        totalInteractions: 0,
        gestureInteractions: 0,
        pictogramInteractions: 0,
        distinctIntentions: 0,
        weekly: [0, 0, 0, 0, 0, 0, 0],
        frequent: [],
      );
    }
    final names = await _Names.load(_db);
    final weekly = [
      for (final d in data['actividad_semanal'] as List<dynamic>)
        (d as Map<String, dynamic>)['cantidad'] as int,
    ];
    return UsageSummary(
      totalInteractions: data['total_interacciones'] as int,
      gestureInteractions: data['interacciones_por_gesto'] as int,
      pictogramInteractions: data['interacciones_por_pictograma'] as int,
      distinctIntentions: data['intenciones_distintas'] as int,
      weekly: weekly,
      frequent: [
        for (final f in data['mas_frecuentes'] as List<dynamic>)
          _frequent(f as Map<String, dynamic>, names),
      ],
    );
  }

  @override
  Future<InteractionRecord?> detail(
      int profileId, InteractionRecord record) async {
    final remoteId = record.interaction.remoteId;
    final uuid = await _profileUuid(profileId);
    if (remoteId == null || uuid == null) return null;
    try {
      final data =
          await _api.get('perfiles/$uuid/interacciones/$remoteId');
      return _record(
          profileId, data as Map<String, dynamic>, await _Names.load(_db));
    } on OfflineException {
      throw const DomainException(offlineMessage);
    } on ApiException catch (e) {
      if (e.status == 404) return null; // HU033: ya no esta disponible
      rethrow;
    }
  }

  /// null si el perfil aun no esta en el backend (p. ej. sin consentimiento).
  Future<dynamic> _query(
      int profileId, String resource, DateTime? from, DateTime? to) async {
    try {
      await beforeQuery?.call();
    } catch (_) {
      // Se consulta igual; lo pendiente se enviara despues.
    }
    final uuid = await _profileUuid(profileId);
    if (uuid == null) return null;
    try {
      return await _api.get('perfiles/$uuid/$resource', query: {
        if (from != null) 'desde': _day(from),
        // El backend recibe `hasta` inclusivo; el periodo local es [from, to).
        if (to != null) 'hasta': _day(to.subtract(const Duration(days: 1))),
      });
    } on OfflineException {
      throw const DomainException(offlineMessage);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<String?> _profileUuid(int profileId) async {
    final rows = await _db.db.query('perfil_nino',
        columns: ['uuid'], where: 'id_perfil = ?', whereArgs: [profileId]);
    return rows.isEmpty ? null : rows.first['uuid'] as String?;
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<InteractionRecord> _record(
      int profileId, Map<String, dynamic> item, _Names names) async {
    final remoteId = item['id_interaccion'] as String;
    final picto = names.pictogram(item['id_pictograma'] as String);
    final gestureId = _localId(item['id_gesto'], 'gesto');
    final intentionId = _localId(item['id_intencion'], 'intencion');
    final local = await _db.db.query('interaccion',
        columns: ['id_interaccion'], where: 'uuid = ?', whereArgs: [remoteId]);
    return InteractionRecord(
      interaction: Interaction(
        id: local.isEmpty ? null : local.first['id_interaccion'] as int,
        remoteId: remoteId,
        at: DateTime.parse(item['fecha_hora'] as String).toLocal(),
        detail: item['detalle'] as String?,
        profileId: profileId,
        pictogramId: picto.id,
        gestureId: gestureId,
        intentionId: intentionId,
      ),
      pictogramName: picto.name,
      pictogramMessage: picto.message,
      pictogramEmoji: picto.emoji,
      pictogramHasImage: picto.hasImage,
      categoryId: picto.categoryId,
      gestureName: gestureId == null ? null : names.gestures[gestureId],
      intentionName: intentionId == null ? null : names.intentions[intentionId],
    );
  }

  FrequentResource _frequent(Map<String, dynamic> f, _Names names) {
    final picto = names.pictogram(f['id_pictograma'] as String);
    return FrequentResource(
      pictogramId: picto.id,
      name: picto.name,
      message: picto.message,
      emoji: picto.emoji,
      count: f['cantidad'] as int,
    );
  }

  static int? _localId(Object? remoteId, String prefix) =>
      remoteId == null ? null : RemoteIds.localFromKey(remoteId as String, prefix);
}

class _Picto {
  const _Picto(this.id, this.name, this.message, this.emoji, this.hasImage,
      this.categoryId);
  final int id;
  final String name;
  final String message;
  final String? emoji;
  final bool hasImage;
  final int categoryId;
}

/// Nombres locales de los catalogos y pictogramas.
class _Names {
  _Names(this._byId, this._byUuid, this.gestures, this.intentions);

  final Map<int, _Picto> _byId;
  final Map<String, _Picto> _byUuid;
  final Map<int, String> gestures;
  final Map<int, String> intentions;
  final _unknown = <String, _Picto>{};

  static Future<_Names> load(GestuVozDatabase db) async {
    final byId = <int, _Picto>{};
    final byUuid = <String, _Picto>{};
    for (final r in await db.db.query('pictograma')) {
      final p = _Picto(
        r['id_pictograma'] as int,
        r['nombre'] as String,
        r['mensaje'] as String,
        r['emoji'] as String?,
        r['imagen'] != null,
        r['id_categoria'] as int,
      );
      byId[p.id] = p;
      final uuid = r['uuid'] as String?;
      if (uuid != null) byUuid[uuid] = p;
    }
    final gestures = {
      for (final r in await db.db.query('gesto'))
        r['id_gesto'] as int: r['nombre'] as String,
    };
    final intentions = {
      for (final r in await db.db.query('intencion_comunicativa'))
        r['id_intencion'] as int: r['nombre'] as String,
    };
    return _Names(byId, byUuid, gestures, intentions);
  }

  _Picto pictogram(String remoteId) {
    final base = RemoteIds.localFromKey(remoteId, 'base');
    final found = base != null ? _byId[base] : _byUuid[remoteId];
    if (found != null) return found;
    // Pictograma eliminado del telefono: se muestra igual en el historial.
    return _unknown.putIfAbsent(
        remoteId,
        () => _Picto(-(_unknown.length + 1), 'Pictograma eliminado', '',
            null, false, 0));
  }
}
