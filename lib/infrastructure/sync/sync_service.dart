import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/child.dart';
import '../persistence/database.dart';
import '../remote/api_client.dart';
import 'sync_log.dart';

/// Identificadores remotos de los catalogos fijos (iguales en todos los
/// telefonos). Los datos que crea el usuario usan su UUID.
abstract final class RemoteIds {
  static String basePictogram(int id) => 'base-$id';
  static String gesture(int id) => 'gesto-$id';
  static String intention(int id) => 'intencion-$id';

  static int? localFromKey(String remoteId, String prefix) =>
      remoteId.startsWith('$prefix-')
          ? int.tryParse(remoteId.substring(prefix.length + 1))
          : null;
}

/// Estado visible de la sincronizacion (RNF-05: informar si no hay
/// conexion con los servicios remotos).
class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.pending = 0,
    this.syncing = false,
    this.lastSync,
  });

  final bool online;
  final int pending;
  final bool syncing;
  final DateTime? lastSync;

  SyncStatus copyWith({
    bool? online,
    int? pending,
    bool? syncing,
    DateTime? lastSync,
  }) =>
      SyncStatus(
        online: online ?? this.online,
        pending: pending ?? this.pending,
        syncing: syncing ?? this.syncing,
        lastSync: lastSync ?? this.lastSync,
      );
}

/// Sincroniza SQLite (telefono) con el backend Django (RF-11, RF-13, RNF-06).
///
/// - Subida: envia la cola `sync_pendiente` y las interacciones pendientes.
/// - Descarga: al iniciar sesion trae perfiles, ninos, consentimiento, voz y
///   pictogramas personalizados del tutor.
/// - Gana el ultimo cambio (`actualizado_en`).
/// - Sin consentimiento vigente no se envia nada de ese perfil; el
///   consentimiento en si siempre se envia.
/// - Sin conexion los cambios quedan pendientes y se envian al reconectar.
class SyncService {
  SyncService(this._db, this._api, {Connectivity? connectivity})
      : _connectivity = connectivity;

  final GestuVozDatabase _db;
  final ApiClient _api;
  final Connectivity? _connectivity;

  final status = ValueNotifier(const SyncStatus());

  int? _tutorId;
  bool _running = false;
  bool _again = false;
  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<void>? _changesSub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  Database get _sql => _db.db;

  // ---------------------------------------------------------------------
  // Ciclo de vida
  // ---------------------------------------------------------------------

  /// Comienza a sincronizar para el tutor con sesion iniciada.
  void start(int tutorId) {
    _tutorId = tutorId;
    _changesSub ??= SyncLog.changes.listen((_) => requestSync());
    _netSub ??= _connectivity?.onConnectivityChanged.listen((result) {
      if (result.any((r) => r != ConnectivityResult.none)) requestSync();
    });
    _periodic ??=
        Timer.periodic(const Duration(minutes: 2), (_) => requestSync());
    requestSync(delay: Duration.zero);
  }

  /// Detiene la sincronizacion (cierre de sesion).
  Future<void> stop() async {
    _tutorId = null;
    _debounce?.cancel();
    _periodic?.cancel();
    _periodic = null;
    await _changesSub?.cancel();
    _changesSub = null;
    await _netSub?.cancel();
    _netSub = null;
  }

  /// Programa un envio (agrupa cambios seguidos).
  void requestSync({Duration delay = const Duration(seconds: 2)}) {
    if (_tutorId == null) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(pushPending()));
  }

  // ---------------------------------------------------------------------
  // Subida
  // ---------------------------------------------------------------------

  static const _order = {
    '${SyncEntity.consent}:${SyncOp.upsert}': 1,
    '${SyncEntity.profile}:${SyncOp.upsert}': 2,
    '${SyncEntity.voice}:${SyncOp.upsert}': 3,
    '${SyncEntity.pictogram}:${SyncOp.upsert}': 4,
    '${SyncEntity.pictogram}:${SyncOp.delete}': 5,
    '${SyncEntity.profile}:${SyncOp.delete}': 6,
  };

  /// Envia todo lo pendiente. Devuelve false si no hubo conexion.
  Future<bool> pushPending() async {
    if (_tutorId == null) return false;
    if (_running) {
      _again = true;
      return true;
    }
    _running = true;
    status.value = status.value.copyWith(syncing: true);
    var online = true;
    var needsPull = false;
    try {
      // Copia: sqflite devuelve listas de solo lectura.
      final items = [...await _sql.query('sync_pendiente')];
      items.sort((a, b) {
        final pa = _order['${a['entidad']}:${a['operacion']}'] ?? 9;
        final pb = _order['${b['entidad']}:${b['operacion']}'] ?? 9;
        return pa != pb
            ? pa.compareTo(pb)
            : (a['id_cola'] as int).compareTo(b['id_cola'] as int);
      });
      for (final item in items) {
        final outcome = await _pushItem(item);
        if (outcome == _Outcome.offline) {
          online = false;
          break;
        }
        if (outcome == _Outcome.conflict) needsPull = true;
        if (outcome == _Outcome.done || outcome == _Outcome.conflict ||
            outcome == _Outcome.discard) {
          await _sql.delete('sync_pendiente',
              where: 'id_cola = ?', whereArgs: [item['id_cola']]);
        }
      }
      if (online) online = await _pushInteractions();
      if (online && needsPull) await pullAll(_tutorId!);
    } on OfflineException {
      online = false;
    } catch (e) {
      debugPrint('Error de sincronizacion: $e');
    } finally {
      _running = false;
      status.value = status.value.copyWith(
        syncing: false,
        online: online,
        pending: await pendingCount(),
        lastSync: online ? DateTime.now() : null,
      );
    }
    if (_again) {
      _again = false;
      requestSync();
    }
    return online;
  }

  Future<int> pendingCount() async {
    final queue = Sqflite.firstIntValue(
            await _sql.rawQuery('SELECT COUNT(*) FROM sync_pendiente')) ??
        0;
    final interactions = Sqflite.firstIntValue(await _sql.rawQuery(
            'SELECT COUNT(*) FROM interaccion WHERE sincronizada = 0')) ??
        0;
    return queue + interactions;
  }

  Future<_Outcome> _pushItem(Map<String, Object?> item) async {
    final entity = item['entidad'] as String;
    final op = item['operacion'] as String;
    final localId = item['id_local'] as int? ?? 0;
    final remoteId = item['id_remoto'] as String? ?? '';
    try {
      if (op == SyncOp.delete) {
        final path = entity == SyncEntity.profile
            ? 'perfiles/$remoteId'
            : 'pictogramas/$remoteId';
        await _api.delete(path);
        return _Outcome.done;
      }
      return await switch (entity) {
        SyncEntity.consent => _pushConsent(localId),
        SyncEntity.profile => _pushProfile(localId),
        SyncEntity.voice => _pushVoice(localId),
        SyncEntity.pictogram => _pushPictogram(localId),
        _ => Future.value(_Outcome.discard),
      };
    } on OfflineException {
      return _Outcome.offline;
    } on ApiException catch (e) {
      return _fromError(e, op);
    }
  }

  _Outcome _fromError(ApiException e, String op) {
    if (e.status == 401) return _Outcome.offline; // sesion invalida: reintentar
    if (e.status == 403 && e.code == 'consentimiento_requerido') {
      return _Outcome.keep;
    }
    if (e.status == 409) return _Outcome.conflict;
    if (e.status == 404 && op == SyncOp.delete) return _Outcome.done;
    if (e.status >= 500) return _Outcome.offline;
    debugPrint('Cambio descartado por el servidor: $e');
    return _Outcome.discard;
  }

  Future<String?> _profileUuid(int profileId) async {
    final rows = await _sql.query('perfil_nino',
        columns: ['uuid'], where: 'id_perfil = ?', whereArgs: [profileId]);
    return rows.isEmpty ? null : rows.first['uuid'] as String?;
  }

  Future<bool> _hasConsent(int profileId) async {
    final rows = await _sql.query('consentimiento',
        columns: ['estado_consentimiento'],
        where: 'id_perfil = ?',
        whereArgs: [profileId]);
    return rows.isNotEmpty && rows.first['estado_consentimiento'] == 'otorgado';
  }

  static String _utc(Object? localIso) =>
      DateTime.parse(localIso as String).toUtc().toIso8601String();

  Future<_Outcome> _pushConsent(int profileId) async {
    final uuid = await _profileUuid(profileId);
    final rows = await _sql.query('consentimiento',
        where: 'id_perfil = ?', whereArgs: [profileId]);
    if (uuid == null || rows.isEmpty) return _Outcome.discard;
    final c = rows.first;
    await _api.put('perfiles/$uuid/consentimiento', {
      'estado_consentimiento': c['estado_consentimiento'],
      'fecha_registro': _utc(c['fecha_registro']),
      'fecha_retiro': c['fecha_retiro'] == null ? null : _utc(c['fecha_retiro']),
      'actualizado_en': c['actualizado_en'],
    });
    return _Outcome.done;
  }

  Future<_Outcome> _pushProfile(int profileId) async {
    final rows = await _sql.rawQuery('''
      SELECT pn.*, n.uuid AS n_uuid, n.nombre, n.fecha_nacimiento, n.genero
      FROM perfil_nino pn JOIN nino n ON n.id_nino = pn.id_nino
      WHERE pn.id_perfil = ?''', [profileId]);
    if (rows.isEmpty) return _Outcome.discard;
    if (!await _hasConsent(profileId)) return _Outcome.keep;
    final p = rows.first;
    final prefs = CommunicationPreferences.fromJson(
        p['preferencias_comunicacion'] as String?);
    final visible = await _sql.rawQuery('''
      SELECT pp.id_pictograma, pp.orden, pi.uuid
      FROM perfil_pictograma pp
      JOIN pictograma pi ON pi.id_pictograma = pp.id_pictograma
      WHERE pp.id_perfil = ? ORDER BY pp.orden''', [profileId]);
    await _api.put('perfiles/${p['uuid']}', {
      'nivel_apoyo': p['nivel_apoyo'],
      'preferencias_de_comunicacion': {
        'gestos_activados': prefs.gesturesEnabled,
        'gestos_habilitados':
            prefs.enabledGestureIds.map(RemoteIds.gesture).toList(),
        'columnas_tablero': prefs.pictogramColumns,
        'alto_contraste': prefs.highContrast,
        'pictogramas': [
          for (final v in visible)
            {
              'id_pictograma': (v['uuid'] as String?) ??
                  RemoteIds.basePictogram(v['id_pictograma'] as int),
              'orden': v['orden'],
            }
        ],
      },
      'estado_perfil': p['estado_perfil'],
      'nino': {
        'id_nino': p['n_uuid'],
        'nombre': p['nombre'],
        'fecha_nacimiento': (p['fecha_nacimiento'] as String).substring(0, 10),
        'genero': p['genero'],
      },
      'actualizado_en': p['actualizado_en'],
    });
    return _Outcome.done;
  }

  Future<_Outcome> _pushVoice(int profileId) async {
    final uuid = await _profileUuid(profileId);
    final rows = await _sql.query('configuracion_voz',
        where: 'id_perfil = ?', whereArgs: [profileId]);
    if (uuid == null || rows.isEmpty) return _Outcome.discard;
    if (!await _hasConsent(profileId)) return _Outcome.keep;
    final v = rows.first;
    await _api.put('perfiles/$uuid/configuracion-voz', {
      'idioma': v['idioma'],
      'tipo_voz': v['tipo_voz'],
      'velocidad': v['velocidad'],
      'volumen': v['volumen'],
      'voz_activada': v['voz_activada'] == 1,
      'actualizado_en': v['actualizado_en'],
    });
    return _Outcome.done;
  }

  Future<_Outcome> _pushPictogram(int pictogramId) async {
    final rows = await _sql.query('pictograma',
        where: 'id_pictograma = ? AND uuid IS NOT NULL',
        whereArgs: [pictogramId]);
    if (rows.isEmpty) return _Outcome.discard;
    // El backend exige un perfil con consentimiento vigente: primero los que
    // usan el pictograma, luego cualquiera del tutor.
    final candidates = await _sql.rawQuery('''
      SELECT pn.uuid FROM perfil_nino pn
      JOIN consentimiento c ON c.id_perfil = pn.id_perfil
      LEFT JOIN perfil_pictograma pp
        ON pp.id_perfil = pn.id_perfil AND pp.id_pictograma = ?
      WHERE pn.id_tutor = ? AND c.estado_consentimiento = 'otorgado'
      ORDER BY pp.id_pictograma IS NULL
      LIMIT 1''', [pictogramId, _tutorId]);
    if (candidates.isEmpty) return _Outcome.keep;
    final p = rows.first;
    final query = {'id_perfil': candidates.first['uuid'] as String};
    await _api.put(
      'pictogramas/${p['uuid']}',
      {
        'nombre': p['nombre'],
        'mensaje': p['mensaje'],
        'id_categoria': p['id_categoria'],
        'actualizado_en': p['actualizado_en'],
      },
      query: query,
    );
    await _pushImage(pictogramId, p, query);
    return _Outcome.done;
  }

  /// Sube la imagen nueva a Cloud Storage, o la quita si se elimino.
  Future<void> _pushImage(int pictogramId, Map<String, Object?> p,
      Map<String, String> query) async {
    final image = p['imagen'] as Uint8List?;
    final ref = p['imagen_ref'] as String?;
    final path = 'pictogramas/${p['uuid']}/imagen';
    String? newRef;
    if (image != null && ref == null) {
      try {
        final r = await _api.putBytes(path, image, query: query);
        newRef = (r as Map<String, dynamic>)['referencia_imagen'] as String?;
      } on ApiException catch (e) {
        // Imagen no valida o muy grande: queda solo en el telefono.
        if (e.status != 400 && e.status != 413) rethrow;
        debugPrint('Imagen no enviada: $e');
        return;
      }
    } else if (image == null && ref != null) {
      await _api.delete(path);
    } else {
      return;
    }
    await _sql.update('pictograma', {'imagen_ref': newRef},
        where: 'id_pictograma = ? AND imagen IS ?',
        whereArgs: [pictogramId, image]);
  }

  /// Interacciones registradas sin conexion, por lotes de hasta 500.
  Future<bool> _pushInteractions() async {
    final profiles = await _sql.rawQuery('''
      SELECT DISTINCT i.id_perfil, pn.uuid FROM interaccion i
      JOIN perfil_nino pn ON pn.id_perfil = i.id_perfil
      JOIN consentimiento c ON c.id_perfil = i.id_perfil
      WHERE i.sincronizada = 0 AND pn.id_tutor = ?
        AND c.estado_consentimiento = 'otorgado' ''', [_tutorId]);
    for (final profile in profiles) {
      while (true) {
        final rows = await _sql.rawQuery('''
          SELECT i.*, p.uuid AS p_uuid FROM interaccion i
          JOIN pictograma p ON p.id_pictograma = i.id_pictograma
          WHERE i.id_perfil = ? AND i.sincronizada = 0
          ORDER BY i.id_interaccion LIMIT 500''', [profile['id_perfil']]);
        if (rows.isEmpty) break;
        try {
          await _api.post('perfiles/${profile['uuid']}/interacciones', {
            'interacciones': [
              for (final r in rows)
                {
                  'id_interaccion': r['uuid'],
                  'fecha_hora': _utc(r['fecha_hora']),
                  'detalle': r['detalle'],
                  'id_pictograma': (r['p_uuid'] as String?) ??
                      RemoteIds.basePictogram(r['id_pictograma'] as int),
                  'id_gesto': r['id_gesto'] == null
                      ? null
                      : RemoteIds.gesture(r['id_gesto'] as int),
                  'id_intencion': r['id_intencion'] == null
                      ? null
                      : RemoteIds.intention(r['id_intencion'] as int),
                }
            ],
          });
        } on OfflineException {
          return false;
        } on ApiException catch (e) {
          if (e.status == 401 || e.status >= 500) return false;
          // Perfil aun no creado en el backend o sin consentimiento: se
          // reintenta en la proxima sincronizacion.
          break;
        }
        final ids = rows.map((r) => r['id_interaccion']).toList();
        await _sql.rawUpdate(
            'UPDATE interaccion SET sincronizada = 1 WHERE id_interaccion '
            'IN (${List.filled(ids.length, '?').join(',')})',
            ids);
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Descarga
  // ---------------------------------------------------------------------

  /// Trae del backend los datos del tutor (nuevo telefono o reinstalacion).
  /// No sobrescribe cambios locales mas recientes ni pendientes de envio.
  Future<void> pullAll(int tutorId) async {
    final pictograms = await _api.get('pictogramas') as List<dynamic>;
    final profiles = await _api.get('perfiles') as List<dynamic>;
    final details = <String, (Map?, Map?)>{};
    for (final p in profiles.cast<Map<String, dynamic>>()) {
      final uuid = p['id_perfil'] as String;
      details[uuid] = (
        await _getOrNull('perfiles/$uuid/consentimiento'),
        await _getOrNull('perfiles/$uuid/configuracion-voz'),
      );
    }
    final downloads = <(int, String)>[];
    await _sql.transaction((txn) async {
      for (final p in pictograms.cast<Map<String, dynamic>>()) {
        final d = await _mergePictogram(txn, p);
        if (d != null) downloads.add(d);
      }
      for (final p in profiles.cast<Map<String, dynamic>>()) {
        final profileId = await _mergeProfile(txn, tutorId, p);
        if (profileId == null) continue;
        final (consent, voice) = details[p['id_perfil']]!;
        if (consent != null) await _mergeConsent(txn, profileId, consent);
        if (voice != null) await _mergeVoice(txn, profileId, voice);
      }
      // Pictogramas descargados: a cargo del perfil que los usa o, si
      // ninguno los usa, del primer perfil del tutor.
      await txn.rawUpdate('''
        UPDATE pictograma SET id_perfil_propietario = COALESCE(
          (SELECT MIN(pp.id_perfil) FROM perfil_pictograma pp
           JOIN perfil_nino pn ON pn.id_perfil = pp.id_perfil
           WHERE pp.id_pictograma = pictograma.id_pictograma
             AND pn.id_tutor = ?),
          (SELECT MIN(id_perfil) FROM perfil_nino WHERE id_tutor = ?))
        WHERE id_perfil_propietario IS NULL AND uuid IS NOT NULL''',
          [tutorId, tutorId]);
    });
    await _downloadImages(downloads);
  }

  /// Descarga las imagenes de Cloud Storage que el telefono no tiene.
  Future<void> _downloadImages(List<(int, String)> downloads) async {
    for (final (localId, ref) in downloads) {
      final rows = await _sql.query('pictograma',
          columns: ['uuid'], where: 'id_pictograma = ?', whereArgs: [localId]);
      if (rows.isEmpty) continue;
      final bytes =
          await _api.getBytes('pictogramas/${rows.first['uuid']}/imagen');
      if (bytes == null) continue;
      await _sql.update('pictograma', {'imagen': bytes, 'imagen_ref': ref},
          where: 'id_pictograma = ?', whereArgs: [localId]);
    }
  }

  Future<Map<String, dynamic>?> _getOrNull(String path) async {
    try {
      return await _api.get(path) as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static bool _remoteIsNewer(Object? remoteTs, Object? localTs) =>
      localTs == null ||
      DateTime.parse(remoteTs as String)
          .isAfter(DateTime.parse(localTs as String));

  static String _local(Object? iso) =>
      DateTime.parse(iso as String).toLocal().toIso8601String();

  Future<bool> _hasPending(Transaction txn, String entity, int localId) async =>
      (await txn.query('sync_pendiente',
              where: 'entidad = ? AND operacion = ? AND id_local = ?',
              whereArgs: [entity, SyncOp.upsert, localId]))
          .isNotEmpty;

  /// Devuelve la imagen que falta descargar (id local, referencia), si hay.
  Future<(int, String)?> _mergePictogram(
      Transaction txn, Map<String, dynamic> p) async {
    final rows = await txn.query('pictograma',
        where: 'uuid = ?', whereArgs: [p['id_pictograma']]);
    final remoteRef = p['referencia_imagen'] as String?;
    final values = {
      'nombre': p['nombre'],
      'mensaje': p['mensaje'],
      'id_categoria': p['id_categoria'],
      'actualizado_en': p['actualizado_en'],
    };
    if (rows.isEmpty) {
      final id = await txn.insert('pictograma', {
        ...values,
        'uuid': p['id_pictograma'],
        // La imagen se descarga despues; mientras tanto se muestra un icono.
        'imagen': null,
        'imagen_ref': null,
        'emoji': '🖼️',
        'id_intencion': null,
      });
      return remoteRef == null ? null : (id, remoteRef);
    }
    final local = rows.first;
    final localId = local['id_pictograma'] as int;
    if (await _hasPending(txn, SyncEntity.pictogram, localId)) return null;
    if (_remoteIsNewer(p['actualizado_en'], local['actualizado_en'])) {
      await txn.update('pictograma', values,
          where: 'id_pictograma = ?', whereArgs: [localId]);
    }
    final localRef = local['imagen_ref'] as String?;
    if (remoteRef != null && remoteRef != localRef) return (localId, remoteRef);
    if (remoteRef == null && localRef != null) {
      // La imagen se quito desde otro telefono.
      await txn.update(
          'pictograma',
          {
            'imagen': null,
            'imagen_ref': null,
            if (local['emoji'] == null) 'emoji': '🖼️',
          },
          where: 'id_pictograma = ?',
          whereArgs: [localId]);
    }
    return null;
  }


  Future<int?> _localPictogram(Transaction txn, String remoteId) async {
    final base = RemoteIds.localFromKey(remoteId, 'base');
    final rows = base != null
        ? await txn.query('pictograma',
            columns: ['id_pictograma'],
            where: 'id_pictograma = ? AND uuid IS NULL',
            whereArgs: [base])
        : await txn.query('pictograma',
            columns: ['id_pictograma'], where: 'uuid = ?', whereArgs: [remoteId]);
    return rows.isEmpty ? null : rows.first['id_pictograma'] as int;
  }

  Future<int?> _mergeProfile(
      Transaction txn, int tutorId, Map<String, dynamic> p) async {
    final nino = p['nino'] as Map<String, dynamic>?;
    if (nino == null) return null;
    final remotePrefs = p['preferencias_de_comunicacion'] as Map<String, dynamic>;
    final prefs = CommunicationPreferences(
      gesturesEnabled: remotePrefs['gestos_activados'] as bool? ?? false,
      enabledGestureIds: [
        for (final g in (remotePrefs['gestos_habilitados'] as List? ?? const []))
          ?RemoteIds.localFromKey(g as String, 'gesto'),
      ],
      pictogramColumns: remotePrefs['columnas_tablero'] as int? ?? 3,
      highContrast: remotePrefs['alto_contraste'] as bool? ?? false,
    );
    final ninoValues = {
      'nombre': nino['nombre'],
      'fecha_nacimiento':
          DateTime.parse(nino['fecha_nacimiento'] as String).toIso8601String(),
      'genero': nino['genero'],
    };
    final profileValues = {
      'nivel_apoyo': p['nivel_apoyo'],
      'preferencias_comunicacion': prefs.toJson(),
      'estado_perfil': p['estado_perfil'],
      'actualizado_en': p['actualizado_en'],
    };

    final rows = await txn.query('perfil_nino',
        where: 'uuid = ?', whereArgs: [p['id_perfil']]);
    final int profileId;
    if (rows.isEmpty) {
      final childId = await txn.insert(
          'nino', {...ninoValues, 'uuid': nino['id_nino']});
      profileId = await txn.insert('perfil_nino', {
        ...profileValues,
        'uuid': p['id_perfil'],
        'id_tutor': tutorId,
        'id_nino': childId,
      });
      const v = (idioma: 'es-ES', velocidad: 0.45, volumen: 1.0);
      await txn.insert('configuracion_voz', {
        'idioma': v.idioma,
        'velocidad': v.velocidad,
        'volumen': v.volumen,
        'voz_activada': 1,
        'id_perfil': profileId,
      });
    } else {
      final local = rows.first;
      profileId = local['id_perfil'] as int;
      if (local['id_tutor'] != tutorId) return null;
      if (await _hasPending(txn, SyncEntity.profile, profileId) ||
          !_remoteIsNewer(p['actualizado_en'], local['actualizado_en'])) {
        return profileId;
      }
      await txn.update('nino', ninoValues,
          where: 'id_nino = ?', whereArgs: [local['id_nino']]);
      await txn.update('perfil_nino', profileValues,
          where: 'id_perfil = ?', whereArgs: [profileId]);
    }
    // Pictogramas visibles y su orden (HU015).
    await txn.delete('perfil_pictograma',
        where: 'id_perfil = ?', whereArgs: [profileId]);
    for (final v in (remotePrefs['pictogramas'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final localId = await _localPictogram(txn, v['id_pictograma'] as String);
      if (localId == null) continue;
      await txn.insert(
          'perfil_pictograma',
          {'id_pictograma': localId, 'id_perfil': profileId, 'orden': v['orden']},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return profileId;
  }

  Future<void> _mergeConsent(
      Transaction txn, int profileId, Map<dynamic, dynamic> c) async {
    final rows = await txn.query('consentimiento',
        where: 'id_perfil = ?', whereArgs: [profileId]);
    final values = {
      'estado_consentimiento': c['estado_consentimiento'],
      'fecha_registro': _local(c['fecha_registro']),
      'fecha_retiro': c['fecha_retiro'] == null ? null : _local(c['fecha_retiro']),
      'id_perfil': profileId,
      'actualizado_en': c['actualizado_en'],
    };
    if (rows.isEmpty) {
      await txn.insert('consentimiento', values);
    } else if (!await _hasPending(txn, SyncEntity.consent, profileId) &&
        _remoteIsNewer(c['actualizado_en'], rows.first['actualizado_en'])) {
      await txn.update('consentimiento', values,
          where: 'id_perfil = ?', whereArgs: [profileId]);
    }
  }

  Future<void> _mergeVoice(
      Transaction txn, int profileId, Map<dynamic, dynamic> v) async {
    final rows = await txn.query('configuracion_voz',
        where: 'id_perfil = ?', whereArgs: [profileId]);
    if (rows.isNotEmpty &&
        (await _hasPending(txn, SyncEntity.voice, profileId) ||
            !_remoteIsNewer(v['actualizado_en'], rows.first['actualizado_en']))) {
      return;
    }
    await txn.insert(
      'configuracion_voz',
      {
        'idioma': v['idioma'],
        'tipo_voz': v['tipo_voz'],
        'velocidad': (v['velocidad'] as num).toDouble(),
        'volumen': (v['volumen'] as num).toDouble(),
        'voz_activada': v['voz_activada'] == true ? 1 : 0,
        'id_perfil': profileId,
        'actualizado_en': v['actualizado_en'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

enum _Outcome {
  /// Enviado correctamente.
  done,

  /// Se mantiene en la cola (p. ej. sin consentimiento).
  keep,

  /// Sin conexion: se detiene y se reintenta luego.
  offline,

  /// El backend tiene una version mas reciente: se descarga.
  conflict,

  /// Rechazado por el backend por datos invalidos: se descarta.
  discard,
}
