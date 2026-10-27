import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../domain/auth.dart';
import '../../domain/child.dart';
import '../../domain/communication.dart';
import '../../domain/consent.dart';
import '../../domain/gesture.dart';
import '../../domain/interaction.dart';
import '../../domain/settings.dart';
import '../sync/sync_log.dart';
import 'database.dart';

/// Implementaciones de los puertos de repositorio sobre SQLite
/// ([GestuVozDatabase]). Adaptadores de infraestructura: el dominio no sabe
/// que existe SQLite.

String _date(DateTime d) => d.toIso8601String();

bool _sameBytes(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
DateTime _parse(Object? v) => DateTime.parse(v as String);

// --------------------------------------------------------------------------
// PADRE_TUTOR
// --------------------------------------------------------------------------
class SqliteAuthRepository implements AuthRepository {
  SqliteAuthRepository(this._db);
  final GestuVozDatabase _db;

  Account _map(Map<String, Object?> r) => Account(
        id: r['id_tutor'] as int,
        email: Email(r['correo_electronico'] as String),
        accessState: r['estado_acceso'] as String,
        password: SecretHash(
          hash: r['contrasena_hash'] as String,
          salt: r['contrasena_sal'] as String,
        ),
      );

  @override
  Future<Account?> findByEmail(Email email) async {
    final rows = await _db.db.query('padre_tutor',
        where: 'correo_electronico = ?', whereArgs: [email.value], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Account?> findById(int id) async {
    final rows = await _db.db.query('padre_tutor',
        where: 'id_tutor = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Account> insert(Account a) async {
    final id = await _db.db.insert('padre_tutor', {
      'correo_electronico': a.email.value,
      'estado_acceso': a.accessState,
      'contrasena_hash': a.password.hash,
      'contrasena_sal': a.password.salt,
    });
    return a.withId(id);
  }

  @override
  Future<Account?> findByRemoteUid(String uid) async {
    final rows = await _db.db.query('padre_tutor',
        where: 'firebase_uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Account> linkRemote({
    required String uid,
    required Email email,
    required SecretHash password,
  }) async {
    return _db.db.transaction((txn) async {
      final values = {
        'correo_electronico': email.value,
        'estado_acceso': AccessState.active,
        'contrasena_hash': password.hash,
        'contrasena_sal': password.salt,
        'firebase_uid': uid,
      };
      // Primero por UID; si no, por correo (cuenta local previa del mismo
      // tutor en este telefono).
      var rows = await txn.query('padre_tutor',
          columns: ['id_tutor'], where: 'firebase_uid = ?', whereArgs: [uid]);
      if (rows.isEmpty) {
        rows = await txn.query('padre_tutor',
            columns: ['id_tutor'],
            where: 'correo_electronico = ?',
            whereArgs: [email.value]);
      }
      final int id;
      if (rows.isEmpty) {
        id = await txn.insert('padre_tutor', values);
      } else {
        id = rows.first['id_tutor'] as int;
        await txn.update('padre_tutor', values,
            where: 'id_tutor = ?', whereArgs: [id]);
      }
      return Account(
        id: id,
        email: email,
        password: password,
      );
    });
  }
}

// --------------------------------------------------------------------------
// NINO + PERFIL_NINO
// --------------------------------------------------------------------------
class SqliteChildProfileRepository implements ChildProfileRepository {
  SqliteChildProfileRepository(this._db);
  final GestuVozDatabase _db;

  static const _select = '''
    SELECT pn.*, n.nombre, n.fecha_nacimiento, n.genero
    FROM perfil_nino pn JOIN nino n ON n.id_nino = pn.id_nino''';

  ChildProfile _map(Map<String, Object?> r) => ChildProfile(
        id: r['id_perfil'] as int,
        tutorId: r['id_tutor'] as int,
        child: Child(
          id: r['id_nino'] as int,
          name: r['nombre'] as String,
          birthDate: _parse(r['fecha_nacimiento']),
          gender: r['genero'] as String?,
        ),
        supportLevel: r['nivel_apoyo'] as String?,
        preferences: CommunicationPreferences.fromJson(
            r['preferencias_comunicacion'] as String?),
        state: r['estado_perfil'] as String,
      );

  @override
  Future<List<ChildProfile>> forTutor(int tutorId) async {
    final rows = await _db.db.rawQuery(
        '$_select WHERE pn.id_tutor = ? ORDER BY n.nombre COLLATE NOCASE',
        [tutorId]);
    return rows.map(_map).toList();
  }

  @override
  Future<ChildProfile?> byId(int profileId) async {
    final rows =
        await _db.db.rawQuery('$_select WHERE pn.id_perfil = ?', [profileId]);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<ChildProfile> create(ChildProfile profile) async {
    return _db.db.transaction((txn) async {
      final now = SyncLog.now();
      final childId = await txn.insert('nino', {
        'nombre': profile.child.name,
        'fecha_nacimiento': _date(profile.child.birthDate),
        'genero': profile.child.gender,
        'uuid': SyncLog.newId(),
      });
      final profileId = await txn.insert('perfil_nino', {
        'nivel_apoyo': profile.supportLevel,
        'preferencias_comunicacion': profile.preferences.toJson(),
        'estado_perfil': profile.state,
        'id_tutor': profile.tutorId,
        'id_nino': childId,
        'uuid': SyncLog.newId(),
        'actualizado_en': now,
      });
      // CONFIGURACION_VOZ inicial (1:1 con el perfil).
      const v = VoiceConfiguration(profileId: 0);
      await txn.insert('configuracion_voz', {
        'idioma': v.language,
        'tipo_voz': v.voiceType,
        'velocidad': v.rate,
        'volumen': v.volume,
        'voz_activada': v.voiceEnabled ? 1 : 0,
        'id_perfil': profileId,
        'actualizado_en': now,
      });
      // El perfil nuevo inicia con los pictogramas semilla seleccionados
      // (los semilla son los que no tienen identificador remoto).
      await txn.rawInsert('''
        INSERT INTO perfil_pictograma (id_pictograma, id_perfil, orden)
        SELECT id_pictograma, ?, id_pictograma FROM pictograma
        WHERE uuid IS NULL''', [profileId]);
      await SyncLog.upsert(txn, SyncEntity.profile, profileId);
      await SyncLog.upsert(txn, SyncEntity.voice, profileId);
      return profile.copyWith(
        id: profileId,
        child: Child(
          id: childId,
          name: profile.child.name,
          birthDate: profile.child.birthDate,
          gender: profile.child.gender,
        ),
      );
    });
  }

  @override
  Future<void> update(ChildProfile profile) async {
    await _db.db.transaction((txn) async {
      await txn.update(
        'nino',
        {
          'nombre': profile.child.name,
          'fecha_nacimiento': _date(profile.child.birthDate),
          'genero': profile.child.gender,
        },
        where: 'id_nino = ?',
        whereArgs: [profile.child.id],
      );
      await txn.update(
        'perfil_nino',
        {
          'nivel_apoyo': profile.supportLevel,
          'preferencias_comunicacion': profile.preferences.toJson(),
          'estado_perfil': profile.state,
        },
        where: 'id_perfil = ?',
        whereArgs: [profile.id],
      );
      await SyncLog.touchProfile(txn, profile.id!);
    });
  }

  @override
  Future<void> delete(int profileId) async {
    await _db.db.transaction((txn) async {
      final rows = await txn.query('perfil_nino',
          columns: ['id_nino', 'uuid'],
          where: 'id_perfil = ?',
          whereArgs: [profileId]);
      if (rows.isEmpty) return;
      final childId = rows.first['id_nino'] as int;
      // HU025: tambien se elimina en la nube. Se descartan los envios
      // pendientes de este perfil.
      for (final entity in [SyncEntity.consent, SyncEntity.voice]) {
        await txn.delete('sync_pendiente',
            where: 'entidad = ? AND id_local = ?',
            whereArgs: [entity, profileId]);
      }
      await SyncLog.delete(txn, SyncEntity.profile,
          localId: profileId, remoteId: rows.first['uuid'] as String?);
      // Pictogramas personalizados que usaba este perfil.
      final customs = (await txn.rawQuery('''
        SELECT p.id_pictograma FROM pictograma p
        LEFT JOIN perfil_pictograma pp
          ON pp.id_pictograma = p.id_pictograma AND pp.id_perfil = ?
        WHERE p.id_perfil_propietario = ?
           OR (pp.id_perfil IS NOT NULL AND p.imagen IS NOT NULL)''',
              [profileId, profileId]))
          .map((r) => r['id_pictograma'] as int)
          .toList();
      // Datos exclusivos del perfil. Interacciones, configuracion de voz,
      // consentimiento y seleccion de pictogramas se borran por cascada.
      await txn.delete('interaccion',
          where: 'id_perfil = ?', whereArgs: [profileId]);
      await txn.delete('perfil_nino',
          where: 'id_perfil = ?', whereArgs: [profileId]);
      await txn.delete('nino', where: 'id_nino = ?', whereArgs: [childId]);
      // Los que siguen en uso por otros perfiles pasan a uno de ellos.
      await txn.rawUpdate('''
        UPDATE pictograma SET id_perfil_propietario = (
          SELECT MIN(pp.id_perfil) FROM perfil_pictograma pp
          WHERE pp.id_pictograma = pictograma.id_pictograma)
        WHERE id_perfil_propietario = ?''', [profileId]);
      // Personalizados: solo si ningun otro perfil los usa ni los referencia.
      for (final id in customs) {
        final inUse = Sqflite.firstIntValue(await txn.rawQuery('''
          SELECT (SELECT COUNT(*) FROM perfil_pictograma WHERE id_pictograma = ?)
               + (SELECT COUNT(*) FROM interaccion WHERE id_pictograma = ?)''',
            [id, id]))!;
        if (inUse == 0) {
          final uuid = (await txn.query('pictograma',
                  columns: ['uuid'],
                  where: 'id_pictograma = ?',
                  whereArgs: [id]))
              .first['uuid'] as String?;
          await txn.delete('pictograma',
              where: 'id_pictograma = ?', whereArgs: [id]);
          await SyncLog.delete(txn, SyncEntity.pictogram,
              localId: id, remoteId: uuid);
        }
      }
    });
  }
}

// --------------------------------------------------------------------------
// CATEGORIA + PICTOGRAMA + PERFIL_PICTOGRAMA
// --------------------------------------------------------------------------
class SqlitePictogramRepository implements PictogramRepository {
  SqlitePictogramRepository(this._db);
  final GestuVozDatabase _db;

  Pictogram _map(Map<String, Object?> r) => Pictogram(
        id: r['id_pictograma'] as int,
        name: r['nombre'] as String,
        message: r['mensaje'] as String,
        categoryId: r['id_categoria'] as int,
        image: r['imagen'] as Uint8List?,
        emoji: r['emoji'] as String?,
        intentionId: r['id_intencion'] as int?,
      );

  @override
  Future<List<PictogramCategory>> categories() async {
    final rows = await _db.db.query('categoria', orderBy: 'id_categoria');
    return rows
        .map((r) => PictogramCategory(
              id: r['id_categoria'] as int,
              name: r['nombre'] as String,
              description: r['descripcion'] as String?,
              availability: r['estado_disponibilidad'] as String,
            ))
        .toList();
  }

  @override
  Future<List<ProfilePictogram>> catalogForProfile(int profileId) async {
    final rows = await _db.db.rawQuery('''
      SELECT p.*, pp.orden FROM pictograma p
      LEFT JOIN perfil_pictograma pp
        ON pp.id_pictograma = p.id_pictograma AND pp.id_perfil = ?
      WHERE p.id_perfil_propietario IS NULL OR p.id_perfil_propietario = ?
      ORDER BY pp.orden IS NULL, pp.orden, p.id_pictograma''',
        [profileId, profileId]);
    return rows
        .map((r) => ProfilePictogram(
              pictogram: _map(r),
              selected: r['orden'] != null,
              order: r['orden'] as int?,
            ))
        .toList();
  }

  @override
  Future<List<Pictogram>> boardForProfile(int profileId) async {
    final rows = await _db.db.rawQuery('''
      SELECT p.* FROM pictograma p
      JOIN perfil_pictograma pp ON pp.id_pictograma = p.id_pictograma
      JOIN categoria c ON c.id_categoria = p.id_categoria
      WHERE pp.id_perfil = ? AND c.estado_disponibilidad = 'disponible'
      ORDER BY pp.orden, p.id_pictograma''', [profileId]);
    return rows.map(_map).toList();
  }

  @override
  Future<Pictogram?> byId(int id) async {
    final rows = await _db.db.query('pictograma',
        where: 'id_pictograma = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Pictogram?> byIntention(int intentionId) async {
    final rows = await _db.db.query('pictograma',
        where: 'id_intencion = ?', whereArgs: [intentionId], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Pictogram> insertCustom(Pictogram p, int profileId) async {
    return _db.db.transaction((txn) async {
      final id = await txn.insert('pictograma', {
        'nombre': p.name,
        'imagen': p.image,
        'mensaje': p.message,
        'emoji': null,
        'id_categoria': p.categoryId,
        'id_intencion': null,
        'id_perfil_propietario': profileId,
        'uuid': SyncLog.newId(),
        'actualizado_en': SyncLog.now(),
      });
      final next = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COALESCE(MAX(orden), 0) + 1 FROM perfil_pictograma '
              'WHERE id_perfil = ?',
              [profileId])) ??
          1;
      await txn.insert('perfil_pictograma',
          {'id_pictograma': id, 'id_perfil': profileId, 'orden': next});
      await SyncLog.upsert(txn, SyncEntity.pictogram, id);
      await SyncLog.touchProfile(txn, profileId);
      return Pictogram(
        id: id,
        name: p.name,
        message: p.message,
        categoryId: p.categoryId,
        image: p.image,
      );
    });
  }

  @override
  Future<void> update(Pictogram p) async {
    await _db.db.transaction((txn) async {
      final before = await txn.query('pictograma',
          columns: ['imagen'], where: 'id_pictograma = ?', whereArgs: [p.id]);
      final imageChanged = before.isNotEmpty &&
          !_sameBytes(before.first['imagen'] as Uint8List?, p.image);
      await txn.update(
        'pictograma',
        {
          'nombre': p.name,
          'imagen': p.image,
          'mensaje': p.message,
          'id_categoria': p.categoryId,
          if (p.isCustom) 'actualizado_en': SyncLog.now(),
          // La imagen nueva se vuelve a subir a Cloud Storage.
          if (imageChanged) 'imagen_ref': null,
        },
        where: 'id_pictograma = ?',
        whereArgs: [p.id],
      );
      // Los pictogramas iniciales son un catalogo fijo y no se sincronizan.
      if (p.isCustom) await SyncLog.upsert(txn, SyncEntity.pictogram, p.id!);
    });
  }

  @override
  Future<void> setSelected(int profileId, int pictogramId, bool selected) async {
    await _db.db.transaction((txn) async {
      if (!selected) {
        await txn.delete('perfil_pictograma',
            where: 'id_perfil = ? AND id_pictograma = ?',
            whereArgs: [profileId, pictogramId]);
      } else {
        await txn.rawInsert('''
          INSERT OR IGNORE INTO perfil_pictograma (id_pictograma, id_perfil, orden)
          VALUES (?, ?, (SELECT COALESCE(MAX(orden), 0) + 1
                         FROM perfil_pictograma WHERE id_perfil = ?))''',
            [pictogramId, profileId, profileId]);
      }
      await SyncLog.touchProfile(txn, profileId);
    });
  }

  @override
  Future<void> reorder(int profileId, List<int> orderedPictogramIds) async {
    await _db.db.transaction((txn) async {
      for (var i = 0; i < orderedPictogramIds.length; i++) {
        await txn.update('perfil_pictograma', {'orden': i + 1},
            where: 'id_perfil = ? AND id_pictograma = ?',
            whereArgs: [profileId, orderedPictogramIds[i]]);
      }
      await SyncLog.touchProfile(txn, profileId);
    });
  }

  @override
  Future<bool> deleteCustomIfUnused(int pictogramId) async {
    return _db.db.transaction((txn) async {
      final used = Sqflite.firstIntValue(await txn.rawQuery(
          'SELECT COUNT(*) FROM interaccion WHERE id_pictograma = ?',
          [pictogramId]))!;
      if (used > 0) return false;
      final rows = await txn.query('pictograma',
          columns: ['uuid'],
          where: 'id_pictograma = ? AND imagen IS NOT NULL',
          whereArgs: [pictogramId]);
      if (rows.isEmpty) return false;
      final profiles = (await txn.query('perfil_pictograma',
              columns: ['id_perfil'],
              where: 'id_pictograma = ?',
              whereArgs: [pictogramId]))
          .map((r) => r['id_perfil'] as int)
          .toList();
      await txn.delete('pictograma',
          where: 'id_pictograma = ?', whereArgs: [pictogramId]);
      await SyncLog.delete(txn, SyncEntity.pictogram,
          localId: pictogramId, remoteId: rows.first['uuid'] as String?);
      for (final profileId in profiles) {
        await SyncLog.touchProfile(txn, profileId);
      }
      return true;
    });
  }
}

// --------------------------------------------------------------------------
// GESTO + INTENCION_COMUNICATIVA
// --------------------------------------------------------------------------
class SqliteGestureRepository implements GestureRepository {
  SqliteGestureRepository(this._db);
  final GestuVozDatabase _db;

  Gesture _map(Map<String, Object?> r) => Gesture(
        id: r['id_gesto'] as int,
        name: r['nombre'] as String,
        description: r['descripcion'] as String?,
        visualRepresentation: r['representacion_visual'] as String?,
        recognitionClass: r['clase_reconocimiento'] as String,
        availability: r['estado_disponibilidad'] as String,
        instructions: r['instrucciones'] as String?,
      );

  CommunicativeIntention _mapIntention(Map<String, Object?> r) =>
      CommunicativeIntention(
        id: r['id_intencion'] as int,
        name: r['nombre'] as String,
        description: r['descripcion'] as String?,
        message: r['mensaje_asociado'] as String,
        gestureId: r['id_gesto'] as int,
      );

  @override
  Future<List<Gesture>> all() async =>
      (await _db.db.query('gesto', orderBy: 'id_gesto')).map(_map).toList();

  @override
  Future<Gesture?> byId(int id) async {
    final rows = await _db.db
        .query('gesto', where: 'id_gesto = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Gesture?> byRecognitionClass(String recognitionClass) async {
    final rows = await _db.db.query('gesto',
        where: 'clase_reconocimiento = ?',
        whereArgs: [recognitionClass],
        limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<CommunicativeIntention?> intentionForGesture(int gestureId) async {
    final rows = await _db.db.query('intencion_comunicativa',
        where: 'id_gesto = ?', whereArgs: [gestureId], limit: 1);
    return rows.isEmpty ? null : _mapIntention(rows.first);
  }

  @override
  Future<CommunicativeIntention?> intentionById(int id) async {
    final rows = await _db.db.query('intencion_comunicativa',
        where: 'id_intencion = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _mapIntention(rows.first);
  }

  @override
  Future<void> updateInstructions(int gestureId, String? instructions) async {
    final v = instructions?.trim();
    await _db.db.update(
        'gesto', {'instrucciones': (v == null || v.isEmpty) ? null : v},
        where: 'id_gesto = ?', whereArgs: [gestureId]);
  }
}

// --------------------------------------------------------------------------
// INTERACCION
// --------------------------------------------------------------------------
class SqliteInteractionRepository implements InteractionRepository {
  SqliteInteractionRepository(this._db);
  final GestuVozDatabase _db;

  static const _select = '''
    SELECT i.*, p.nombre AS p_nombre, p.mensaje AS p_mensaje,
           p.emoji AS p_emoji, (p.imagen IS NOT NULL) AS p_tiene_imagen,
           p.id_categoria AS p_categoria,
           g.nombre AS g_nombre, ic.nombre AS ic_nombre
    FROM interaccion i
    JOIN pictograma p ON p.id_pictograma = i.id_pictograma
    LEFT JOIN gesto g ON g.id_gesto = i.id_gesto
    LEFT JOIN intencion_comunicativa ic ON ic.id_intencion = i.id_intencion''';

  InteractionRecord _map(Map<String, Object?> r) => InteractionRecord(
        interaction: Interaction(
          id: r['id_interaccion'] as int,
          remoteId: r['uuid'] as String?,
          at: _parse(r['fecha_hora']),
          detail: r['detalle'] as String?,
          profileId: r['id_perfil'] as int,
          pictogramId: r['id_pictograma'] as int,
          gestureId: r['id_gesto'] as int?,
          intentionId: r['id_intencion'] as int?,
        ),
        pictogramName: r['p_nombre'] as String,
        pictogramMessage: r['p_mensaje'] as String,
        pictogramEmoji: r['p_emoji'] as String?,
        pictogramHasImage: (r['p_tiene_imagen'] as int) == 1,
        categoryId: r['p_categoria'] as int,
        gestureName: r['g_nombre'] as String?,
        intentionName: r['ic_nombre'] as String?,
      );

  @override
  Future<Interaction> add(Interaction i) async {
    final id = await _db.db.insert('interaccion', {
      'fecha_hora': _date(i.at),
      'detalle': i.detail,
      'id_intencion': i.intentionId,
      'id_pictograma': i.pictogramId,
      'id_gesto': i.gestureId,
      'id_perfil': i.profileId,
      // Se envia al backend en lote; queda pendiente si no hay conexion.
      'uuid': SyncLog.newId(),
      'sincronizada': 0,
    });
    SyncLog.notify();
    return Interaction(
      id: id,
      at: i.at,
      detail: i.detail,
      profileId: i.profileId,
      pictogramId: i.pictogramId,
      gestureId: i.gestureId,
      intentionId: i.intentionId,
    );
  }

  @override
  Future<List<InteractionRecord>> recordsForProfile(
    int profileId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final where = StringBuffer('WHERE i.id_perfil = ?');
    final args = <Object>[profileId];
    if (from != null) {
      where.write(' AND i.fecha_hora >= ?');
      args.add(_date(from));
    }
    if (to != null) {
      where.write(' AND i.fecha_hora < ?');
      args.add(_date(to));
    }
    final rows = await _db.db.rawQuery(
        '$_select $where ORDER BY i.fecha_hora DESC, i.id_interaccion DESC',
        args);
    return rows.map(_map).toList();
  }

  @override
  Future<InteractionRecord?> recordById(int id) async {
    final rows =
        await _db.db.rawQuery('$_select WHERE i.id_interaccion = ?', [id]);
    return rows.isEmpty ? null : _map(rows.first);
  }
}

// --------------------------------------------------------------------------
// CONFIGURACION_VOZ
// --------------------------------------------------------------------------
class SqliteVoiceConfigurationRepository
    implements VoiceConfigurationRepository {
  SqliteVoiceConfigurationRepository(this._db);
  final GestuVozDatabase _db;

  @override
  Future<VoiceConfiguration> forProfile(int profileId) async {
    final rows = await _db.db.query('configuracion_voz',
        where: 'id_perfil = ?', whereArgs: [profileId], limit: 1);
    if (rows.isEmpty) return VoiceConfiguration(profileId: profileId);
    final r = rows.first;
    return VoiceConfiguration(
      id: r['id_configuracion_voz'] as int,
      profileId: profileId,
      language: r['idioma'] as String,
      voiceType: r['tipo_voz'] as String?,
      rate: (r['velocidad'] as num).toDouble(),
      volume: (r['volumen'] as num).toDouble(),
      voiceEnabled: (r['voz_activada'] as int) == 1,
    );
  }

  @override
  Future<void> save(VoiceConfiguration c) async {
    await _db.db.transaction((txn) async {
      await txn.insert(
        'configuracion_voz',
        {
          'idioma': c.language,
          'tipo_voz': c.voiceType,
          'velocidad': c.rate,
          'volumen': c.volume,
          'voz_activada': c.voiceEnabled ? 1 : 0,
          'id_perfil': c.profileId,
          'actualizado_en': SyncLog.now(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await SyncLog.upsert(txn, SyncEntity.voice, c.profileId);
    });
  }
}

// --------------------------------------------------------------------------
// CONSENTIMIENTO
// --------------------------------------------------------------------------
class SqliteConsentRepository implements ConsentRepository {
  SqliteConsentRepository(this._db);
  final GestuVozDatabase _db;

  Consent _map(Map<String, Object?> r) => Consent(
        id: r['id_consentimiento'] as int,
        profileId: r['id_perfil'] as int,
        state: ConsentStateX.fromDb(r['estado_consentimiento'] as String?),
        registeredAt: _parse(r['fecha_registro']),
        withdrawnAt: r['fecha_retiro'] == null ? null : _parse(r['fecha_retiro']),
      );

  @override
  Future<Consent?> forProfile(int profileId) async {
    final rows = await _db.db.query('consentimiento',
        where: 'id_perfil = ?', whereArgs: [profileId], limit: 1);
    return rows.isEmpty ? null : _map(rows.first);
  }

  @override
  Future<Consent> save(Consent c) async {
    final values = {
      'estado_consentimiento': c.state.dbValue,
      'fecha_registro': _date(c.registeredAt),
      'fecha_retiro': c.withdrawnAt == null ? null : _date(c.withdrawnAt!),
      'id_perfil': c.profileId,
      'actualizado_en': SyncLog.now(),
    };
    await _db.db.transaction((txn) async {
      final updated = await txn.update('consentimiento', values,
          where: 'id_perfil = ?', whereArgs: [c.profileId]);
      if (updated == 0) await txn.insert('consentimiento', values);
      await SyncLog.upsert(txn, SyncEntity.consent, c.profileId);
    });
    return (await forProfile(c.profileId))!;
  }
}
