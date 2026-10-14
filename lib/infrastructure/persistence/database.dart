import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../seed/gesture_seed.dart';
import '../seed/pictogram_seed.dart';

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
  /// prueba (clases `gesto_*`).
  static const schemaVersion = 2;

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
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _migrateToV2(db);
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
          'instrucciones': null,
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
}
