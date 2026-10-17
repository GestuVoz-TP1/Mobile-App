import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Entidades que se sincronizan con el backend.
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

/// Registro local de cambios por sincronizar (tabla `sync_pendiente`).
///
/// Los repositorios lo llaman dentro de la misma transaccion en que guardan
/// el dato, para que ningun cambio quede sin su aviso de sincronizacion. La
/// carga util se arma al enviar, con el estado mas reciente del dato.
abstract final class SyncLog {
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  static String now() => DateTime.now().toUtc().toIso8601String();

  /// Marca un dato como pendiente de enviar (crear o actualizar).
  static Future<void> upsert(
      DatabaseExecutor ex, String entity, int localId) async {
    await ex.rawInsert('''
      INSERT OR IGNORE INTO sync_pendiente
        (entidad, id_local, id_remoto, operacion, creado_en)
      VALUES (?, ?, '', ?, ?)''', [entity, localId, SyncOp.upsert, now()]);
  }

  /// Marca un dato como pendiente de eliminar en el backend. Descarta los
  /// envios pendientes de ese mismo dato.
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
  }

  /// Registra que el perfil cambio (datos del nino o preferencias, incluidos
  /// los pictogramas visibles y su orden).
  static Future<void> touchProfile(DatabaseExecutor ex, int profileId) async {
    await ex.update('perfil_nino', {'actualizado_en': now()},
        where: 'id_perfil = ?', whereArgs: [profileId]);
    await upsert(ex, SyncEntity.profile, profileId);
  }
}
