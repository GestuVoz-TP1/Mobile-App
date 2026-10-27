import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../seed/gesture_seed.dart';
import '../seed/pictogram_seed.dart';
import '../sync/sync_log.dart';

/// Base de datos local SQLite de GestuVoz (OB2, RT-06).
///
/// El esquema sigue el diagrama fisico de OB2 (Fig. 6). Cambios respecto al
/// diagrama: contrasena local en PADRE_TUTOR (hasta integrar Firebase), FK
/// opcionales PICTOGRAMA.id_intencion e INTERACCION.id_gesto/id_intencion,
/// y columnas `emoji`, `orden`, `instrucciones` y `voz_activada`.
class GestuVozDatabase {
  GestuVozDatabase._(this.db);
  final Database db;

  static const fileName = 'gestuvoz.db';

  /// v1: esquema inicial. v2: textos de gestos iniciales sin etiquetas de
  /// prueba (clases `gesto_*`). v3: sincronizacion con el backend
  /// (identificadores remotos, fecha de cambio, cola de pendientes y UID de
  /// Firebase del tutor). v6: gestos que reconoce el modelo entrenado.
  /// v7: instrucciones sugeridas y emoji con la forma de la mano. v8: las
  /// instrucciones ya no piden quedarse quieto (reconocimiento continuo).
  static const schemaVersion = 8;

  /// Abre (o crea) la base de datos. [path] permite usar una base en memoria
  /// en las pruebas (`inMemoryDatabasePath`).
  static Future<GestuVozDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await _createSchema(db);
          await _seed(db);
          await _migrateToV3(db);
          await _migrateToV4(db);
          await _migrateCustomOwner(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _migrateToV2(db);
          // Idempotentes: tambien completan una base creada por la rama del
          // prototipo sin conexion, que usa otra numeracion de versiones.
          await _migrateToV3(db);
          await _migrateToV4(db);
          await _migrateCustomOwner(db);
          await _migrateModelGestures(db);
          await _migrateGestureGuides(db);
        },
      ),
    );
    return GestuVozDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE padre_tutor (
          id_tutor            INTEGER PRIMARY KEY AUTOINCREMENT,
          correo_electronico  TEXT NOT NULL UNIQUE,
          estado_acceso       TEXT NOT NULL,
          contrasena_hash     TEXT NOT NULL,
          contrasena_sal      TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE nino (
          id_nino           INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre            TEXT NOT NULL,
          fecha_nacimiento  TEXT NOT NULL,
          genero            TEXT
        )''')
      ..execute('''
        CREATE TABLE perfil_nino (
          id_perfil                  INTEGER PRIMARY KEY AUTOINCREMENT,
          nivel_apoyo                TEXT,
          preferencias_comunicacion  TEXT,
          estado_perfil              TEXT NOT NULL,
          id_tutor  INTEGER NOT NULL REFERENCES padre_tutor(id_tutor) ON DELETE CASCADE,
          id_nino   INTEGER NOT NULL UNIQUE REFERENCES nino(id_nino) ON DELETE CASCADE
        )''')
      ..execute('''
        CREATE TABLE categoria (
          id_categoria           INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre                 TEXT NOT NULL,
          descripcion            TEXT,
          estado_disponibilidad  TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE gesto (
          id_gesto               INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre                 TEXT NOT NULL,
          descripcion            TEXT,
          representacion_visual  TEXT,
          clase_reconocimiento   TEXT NOT NULL UNIQUE,
          estado_disponibilidad  TEXT NOT NULL,
          instrucciones          TEXT
        )''')
      ..execute('''
        CREATE TABLE intencion_comunicativa (
          id_intencion      INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre            TEXT NOT NULL,
          descripcion       TEXT,
          mensaje_asociado  TEXT NOT NULL,
          id_gesto  INTEGER NOT NULL UNIQUE REFERENCES gesto(id_gesto)
        )''')
      ..execute('''
        CREATE TABLE pictograma (
          id_pictograma  INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre         TEXT NOT NULL,
          imagen         BLOB,
          mensaje        TEXT NOT NULL,
          emoji          TEXT,
          id_categoria  INTEGER NOT NULL REFERENCES categoria(id_categoria),
          id_intencion  INTEGER UNIQUE REFERENCES intencion_comunicativa(id_intencion)
        )''')
      ..execute('''
        CREATE TABLE perfil_pictograma (
          id_pictograma  INTEGER NOT NULL REFERENCES pictograma(id_pictograma) ON DELETE CASCADE,
          id_perfil      INTEGER NOT NULL REFERENCES perfil_nino(id_perfil) ON DELETE CASCADE,
          orden          INTEGER NOT NULL,
          PRIMARY KEY (id_pictograma, id_perfil)
        )''')
      ..execute('''
        CREATE TABLE configuracion_voz (
          id_configuracion_voz  INTEGER PRIMARY KEY AUTOINCREMENT,
          idioma        TEXT NOT NULL,
          tipo_voz      TEXT,
          velocidad     REAL NOT NULL,
          volumen       REAL NOT NULL,
          voz_activada  INTEGER NOT NULL,
          id_perfil  INTEGER NOT NULL UNIQUE REFERENCES perfil_nino(id_perfil) ON DELETE CASCADE
        )''')
      ..execute('''
        CREATE TABLE consentimiento (
          id_consentimiento      INTEGER PRIMARY KEY AUTOINCREMENT,
          estado_consentimiento  TEXT NOT NULL,
          fecha_registro         TEXT NOT NULL,
          fecha_retiro           TEXT,
          id_perfil  INTEGER NOT NULL UNIQUE REFERENCES perfil_nino(id_perfil) ON DELETE CASCADE
        )''')
      ..execute('''
        CREATE TABLE interaccion (
          id_interaccion  INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha_hora      TEXT NOT NULL,
          detalle         TEXT,
          id_intencion   INTEGER REFERENCES intencion_comunicativa(id_intencion),
          id_pictograma  INTEGER NOT NULL REFERENCES pictograma(id_pictograma),
          id_gesto       INTEGER REFERENCES gesto(id_gesto),
          id_perfil      INTEGER NOT NULL REFERENCES perfil_nino(id_perfil) ON DELETE CASCADE
        )''')
      ..execute('CREATE INDEX idx_interaccion_perfil_fecha '
          'ON interaccion(id_perfil, fecha_hora)')
      ..execute('CREATE INDEX idx_perfil_pictograma_orden '
          'ON perfil_pictograma(id_perfil, orden)');
    await batch.commit(noResult: true);
  }

  /// Carga los datos iniciales: categorias y pictogramas existentes del
  /// prototipo y los gestos iniciales con su intencion.
  static Future<void> _seed(Database db) async {
    await db.transaction((txn) async {
      final catIdByKey = <String, int>{};
      for (final c in kSeedCategories) {
        await txn.insert('categoria', {
          'id_categoria': c.id,
          'nombre': c.name,
          'descripcion': null,
          'estado_disponibilidad': 'disponible',
        });
        catIdByKey[c.key] = c.id;
      }
      final pictoIdByKey = <String, int>{};
      for (final s in kSeedPictograms) {
        pictoIdByKey[s.key] = await txn.insert('pictograma', {
          'nombre': s.label,
          'imagen': null,
          'mensaje': s.speech,
          'emoji': s.emoji,
          'id_categoria': catIdByKey[s.categoryKey],
          'id_intencion': null,
        });
      }
      for (final g in kSeedGestures) {
        final gestureId = await txn.insert('gesto', {
          'nombre': g.name,
          'descripcion': null,
          'representacion_visual': g.visual,
          'clase_reconocimiento': g.recognitionClass,
          'estado_disponibilidad': 'disponible',
          'instrucciones': g.instructions,
        });
        final pictoId = pictoIdByKey[g.pictogramKey]!;
        final message = kSeedPictograms
            .firstWhere((s) => s.key == g.pictogramKey)
            .speech;
        final intentionId = await txn.insert('intencion_comunicativa', {
          'nombre': g.intentionName,
          'descripcion': null,
          'mensaje_asociado': message,
          'id_gesto': gestureId,
        });
        await txn.update('pictograma', {'id_intencion': intentionId},
            where: 'id_pictograma = ?', whereArgs: [pictoId]);
      }
    });
  }

  /// v2: quita las etiquetas de prueba de los gestos iniciales en bases ya
  /// creadas con v1. No borra datos del usuario.
  static Future<void> _migrateToV2(Database db) async {
    await db.transaction((txn) async {
      for (final g in kSeedGestures) {
        final oldClass = g.recognitionClass.replaceFirst('gesto_', 'demo_');
        final rows = await txn.query('gesto',
            columns: ['id_gesto'],
            where: 'clase_reconocimiento = ?',
            whereArgs: [oldClass]);
        if (rows.isEmpty) continue;
        final id = rows.first['id_gesto'] as int;
        await txn.update(
            'gesto',
            {
              'clase_reconocimiento': g.recognitionClass,
              'descripcion': null,
            },
            where: 'id_gesto = ?',
            whereArgs: [id]);
        await txn.update(
            'intencion_comunicativa',
            {'nombre': g.intentionName, 'descripcion': null},
            where: 'id_gesto = ?',
            whereArgs: [id]);
      }
      await txn.rawUpdate(
          "UPDATE interaccion SET detalle = 'Gesto reconocido' "
          "WHERE detalle LIKE 'Gesto reconocido (%'");
    });
  }

  /// v3: columnas y tabla para sincronizar con el backend (Cloud Firestore).
  /// - `uuid`: identificador remoto (documento en Firestore) de lo que crea el
  ///   usuario. Los catalogos fijos usan claves `base-<id>`, `gesto-<id>`,
  ///   `intencion-<id>`.
  /// - `actualizado_en`: fecha del ultimo cambio (gana el ultimo cambio).
  /// - `sincronizada`: interacciones ya enviadas.
  /// - `sync_pendiente`: cola de cambios por enviar.
  /// - `firebase_uid`: usuario de Firebase Authentication del tutor.
  /// Es aditiva: conserva los datos existentes y les asigna su UUID.
  static Future<void> _migrateToV3(Database db) async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      // Idempotente: solo agrega lo que falta.
      Future<void> addColumn(String table, String column, String type) async {
        final cols = await txn.rawQuery('PRAGMA table_info($table)');
        if (cols.any((c) => c['name'] == column)) return;
        await txn.execute('ALTER TABLE $table ADD COLUMN $column $type');
      }

      await addColumn('padre_tutor', 'firebase_uid', 'TEXT');
      await addColumn('nino', 'uuid', 'TEXT');
      await addColumn('perfil_nino', 'uuid', 'TEXT');
      await addColumn('perfil_nino', 'actualizado_en', 'TEXT');
      await addColumn('pictograma', 'uuid', 'TEXT');
      await addColumn('pictograma', 'actualizado_en', 'TEXT');
      await addColumn('configuracion_voz', 'actualizado_en', 'TEXT');
      await addColumn('consentimiento', 'actualizado_en', 'TEXT');
      await addColumn('interaccion', 'uuid', 'TEXT');
      await addColumn(
          'interaccion', 'sincronizada', 'INTEGER NOT NULL DEFAULT 0');
      for (final sql in [
        '''CREATE TABLE IF NOT EXISTS sync_pendiente (
             id_cola     INTEGER PRIMARY KEY AUTOINCREMENT,
             entidad     TEXT NOT NULL,
             id_local    INTEGER,
             id_remoto   TEXT,
             operacion   TEXT NOT NULL,
             creado_en   TEXT NOT NULL
           )''',
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_pendiente '
            'ON sync_pendiente(entidad, operacion, id_local, id_remoto)',
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_tutor_uid '
            'ON padre_tutor(firebase_uid)',
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_nino_uuid ON nino(uuid)',
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_perfil_uuid ON perfil_nino(uuid)',
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_pictograma_uuid '
            'ON pictograma(uuid)',
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_interaccion_uuid '
            'ON interaccion(uuid)',
      ]) {
        await txn.execute(sql);
      }
      // UUID para los datos que ya existian (no para los catalogos fijos).
      Future<void> backfill(String table, String idCol, String where) async {
        final rows =
            await txn.query(table, columns: [idCol], where: where);
        for (final r in rows) {
          await txn.update(table, {'uuid': uuid.v4()},
              where: '$idCol = ?', whereArgs: [r[idCol]]);
        }
      }

      await backfill('nino', 'id_nino', 'uuid IS NULL');
      await backfill('perfil_nino', 'id_perfil', 'uuid IS NULL');
      await backfill(
          'pictograma', 'id_pictograma', 'uuid IS NULL AND imagen IS NOT NULL');
      await backfill('interaccion', 'id_interaccion', 'uuid IS NULL');
      for (final table in [
        'perfil_nino',
        'configuracion_voz',
        'consentimiento',
      ]) {
        await txn.update(table, {'actualizado_en': now},
            where: 'actualizado_en IS NULL');
      }
      await txn.update('pictograma', {'actualizado_en': now},
          where: 'actualizado_en IS NULL AND imagen IS NOT NULL');
    });
  }

  /// Dueño de cada pictograma personalizado: solo aparece en el catálogo del
  /// perfil que lo creó (no en otros perfiles ni en otras cuentas del mismo
  /// teléfono). Idempotente.
  static Future<void> _migrateCustomOwner(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(pictograma)');
    if (!cols.any((c) => c['name'] == 'id_perfil_propietario')) {
      await db.execute(
          'ALTER TABLE pictograma ADD COLUMN id_perfil_propietario INTEGER');
    }
    // Los que ya existian quedan a cargo del primer perfil que los usa.
    await db.rawUpdate('''
      UPDATE pictograma SET id_perfil_propietario = (
        SELECT MIN(pp.id_perfil) FROM perfil_pictograma pp
        WHERE pp.id_pictograma = pictograma.id_pictograma)
      WHERE id_perfil_propietario IS NULL AND uuid IS NOT NULL''');
  }

  /// v4: ruta en Cloud Storage de la imagen guardada en el telefono
  /// (`referencia_imagen`). Nula si la imagen aun no se sube o no se descarga.
  static Future<void> _migrateToV4(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(pictograma)');
    if (cols.any((c) => c['name'] == 'imagen_ref')) return;
    await db.execute('ALTER TABLE pictograma ADD COLUMN imagen_ref TEXT');
  }

  /// v6: agrega los gestos de [kSeedGestures] que falten (los que reconoce
  /// el modelo entrenado), con su intencion y su pictograma, y los habilita
  /// en los perfiles existentes. Idempotente.
  static Future<void> _migrateModelGestures(Database db) async {
    await db.transaction((txn) async {
      final added = <int>[];
      Future<int?> freeId(String table, String column, int id) async =>
          (await txn.query(table, where: '$column = ?', whereArgs: [id]))
                  .isEmpty
              ? id
              : null;
      for (final (index, g) in kSeedGestures.indexed) {
        final exists = await txn.query('gesto',
            columns: ['id_gesto'],
            where: 'clase_reconocimiento = ?',
            whereArgs: [g.recognitionClass]);
        if (exists.isNotEmpty) continue;
        final picto = kSeedPictograms.firstWhere((s) => s.key == g.pictogramKey);
        final pictoRows = await txn.query('pictograma',
            columns: ['id_pictograma'],
            where: 'nombre = ? AND mensaje = ? AND uuid IS NULL '
                'AND id_intencion IS NULL',
            whereArgs: [picto.label, picto.speech],
            orderBy: 'id_pictograma',
            limit: 1);
        if (pictoRows.isEmpty) continue;
        // Mismo identificador que en una instalacion nueva (orden de la
        // semilla), porque el backend lo usa como `gesto-<id>`.
        final gestureId = await txn.insert('gesto', {
          'id_gesto': await freeId('gesto', 'id_gesto', index + 1),
          'nombre': g.name,
          'descripcion': null,
          'representacion_visual': g.visual,
          'clase_reconocimiento': g.recognitionClass,
          'estado_disponibilidad': 'disponible',
          'instrucciones': g.instructions,
        });
        final intentionId = await txn.insert('intencion_comunicativa', {
          'id_intencion': await freeId(
              'intencion_comunicativa', 'id_intencion', index + 1),
          'nombre': g.intentionName,
          'descripcion': null,
          'mensaje_asociado': picto.speech,
          'id_gesto': gestureId,
        });
        await txn.update('pictograma', {'id_intencion': intentionId},
            where: 'id_pictograma = ?',
            whereArgs: [pictoRows.first['id_pictograma']]);
        added.add(gestureId);
      }
      if (added.isEmpty) return;
      final profiles = await txn.query('perfil_nino',
          columns: ['id_perfil', 'preferencias_comunicacion']);
      for (final r in profiles) {
        final raw = r['preferencias_comunicacion'] as String?;
        final prefs = raw == null
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
        final enabled = ((prefs['gestos_habilitados'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toSet()
          ..addAll(added);
        prefs['gestos_habilitados'] = enabled.toList()..sort();
        final id = r['id_perfil'] as int;
        await txn.update(
            'perfil_nino', {'preferencias_comunicacion': jsonEncode(prefs)},
            where: 'id_perfil = ?', whereArgs: [id]);
        await SyncLog.touchProfile(txn, id);
      }
    });
  }

  /// v7: emoji con la forma de la mano y, si el tutor aun no escribio
  /// instrucciones, los pasos sugeridos. Idempotente.
  static Future<void> _migrateGestureGuides(Database db) async {
    await db.transaction((txn) async {
      for (final g in kSeedGestures) {
        await txn.update('gesto', {'representacion_visual': g.visual},
            where: 'clase_reconocimiento = ?', whereArgs: [g.recognitionClass]);
        if (g.instructions == null) continue;
        await txn.update('gesto', {'instrucciones': g.instructions},
            where: "clase_reconocimiento = ? AND "
                "(instrucciones IS NULL OR TRIM(instrucciones) = '' "
                'OR instrucciones = ?)',
            whereArgs: [
              g.recognitionClass,
              // Texto de v7, si el tutor no lo cambio.
              '${g.instructions}\nMantén el gesto quieto unos 3 segundos.',
            ]);
      }
    });
  }
}
