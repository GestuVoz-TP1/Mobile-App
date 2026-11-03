import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

abstract final class SyncEntity {
  static const profile = 'perfil';
  static const consent = 'consentimiento';
  static const voice = 'voz';
  static const pictogram = 'pictograma';
}

abstract final class SyncOp {
  static const upsert = 'upsert';
  static const delete = 'delete';
}

abstract final class SyncLog {
  static const _uuid = Uuid();
  static final _changes = StreamController<void>.broadcast();

  static String newId() => _uuid.v4();

  static String now() => DateTime.now().toUtc().toIso8601String();

  static Stream<void> get changes => _changes.stream;
  static void notify() => _changes.add(null);

  static Future<void> upsert(
      DatabaseExecutor ex, String entity, int localId) async {
    await ex.rawInsert('''
      INSERT OR IGNORE INTO sync_pendiente
        (entidad, id_local, id_remoto, operacion, creado_en)
      VALUES (?, ?, '', ?, ?)''', [entity, localId, SyncOp.upsert, now()]);
    notify();
  }

  static Future<void> delete(
    DatabaseExecutor ex,
    String entity, {
    required int localId,
    required String? remoteId,
  }) async {
    await ex.delete('sync_pendiente',
        where: 'entidad = ? AND operacion = ? AND id_local = ?',
        whereArgs: [entity, SyncOp.upsert, localId]);
    if (remoteId == null || remoteId.isEmpty) return;
    await ex.rawInsert('''
      INSERT OR IGNORE INTO sync_pendiente
        (entidad, id_local, id_remoto, operacion, creado_en)
      VALUES (?, 0, ?, ?, ?)''', [entity, remoteId, SyncOp.delete, now()]);
    notify();
  }

  static Future<void> touchProfile(DatabaseExecutor ex, int profileId) async {
    await ex.update('perfil_nino', {'actualizado_en': now()},
        where: 'id_perfil = ?', whereArgs: [profileId]);
    await upsert(ex, SyncEntity.profile, profileId);
  }
}
