import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/application/auth_service.dart';
import 'package:gestuvoz/application/communication_service.dart';
import 'package:gestuvoz/application/gesture_service.dart';
import 'package:gestuvoz/application/interaction_service.dart';
import 'package:gestuvoz/application/privacy_service.dart';
import 'package:gestuvoz/application/profile_service.dart';
import 'package:gestuvoz/application/settings_service.dart';
import 'package:gestuvoz/domain/child.dart';
import 'package:gestuvoz/domain/consent.dart';
import 'package:gestuvoz/domain/ml.dart';
import 'package:gestuvoz/infrastructure/ml/test_mode_gesture_recognition_service.dart';
import 'package:gestuvoz/infrastructure/persistence/database.dart';
import 'package:gestuvoz/infrastructure/persistence/repositories.dart';
import 'package:gestuvoz/infrastructure/security/secret_hasher_impl.dart';
import 'package:gestuvoz/infrastructure/seed/gesture_seed.dart';
import 'package:gestuvoz/infrastructure/seed/pictogram_seed.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _App {
  _App(this.db)
      : auth = AuthService(SqliteAuthRepository(db), Sha256SecretHasher()),
        profiles = ProfileService(
            SqliteChildProfileRepository(db), SqliteGestureRepository(db)),
        communication = CommunicationService(SqlitePictogramRepository(db)),
        privacy = PrivacyService(SqliteConsentRepository(db)),
        voice = SettingsService(SqliteVoiceConfigurationRepository(db)),
        interactions = InteractionService(SqliteInteractionRepository(db),
            SqliteConsentRepository(db));

  final GestuVozDatabase db;
  final AuthService auth;
  final ProfileService profiles;
  final CommunicationService communication;
  final PrivacyService privacy;
  final SettingsService voice;
  final InteractionService interactions;

  static Future<_App> open(String path) async => _App(
      await GestuVozDatabase.open(path: path, factory: databaseFactoryFfi));
}

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late String path;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gestuvoz_test_');
    path = '${tmp.path}/gestuvoz.db';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(_App, int tutorId, int profileId)> withProfile() async {
    final app = await _App.open(path);
    final tutor = await app.auth.register(const RegistrationForm(
        email: 'maria@email.com',
        password: 'secreta123',
        passwordConfirm: 'secreta123'));
    final profile = await app.profiles.create(
        tutor.id!,
        ProfileForm(
            name: 'Valentina López', birthDate: DateTime(2019, 5, 14)));
    return (app, tutor.id!, profile.id!);
  }

  test('La semilla conserva las 10 categorías y los 127 pictogramas', () async {
    final app = await _App.open(path);
    final cats = await app.communication.categories();
    expect(cats.length, kSeedCategories.length);
    final rows = await app.db.db.query('pictograma');
    expect(rows.length, kSeedPictograms.length);
    expect(kSeedPictograms.length, 127);
    final gestures = await app.db.db.query('gesto');
    expect(gestures.length, kSeedGestures.length);
    expect(gestures.every((g) => (g['clase_reconocimiento'] as String)
        .startsWith('gesto_')), isTrue);
    expect(gestures.every((g) => g['instrucciones'] != null), isTrue);
    await app.db.close();
  });

  test('Migración v1 → v2: limpia etiquetas de prueba sin perder datos',
      () async {
    final (app, _, profileId) = await withProfile();
    final db = app.db.db;
    for (final g in kSeedGestures) {
      final old = g.recognitionClass.replaceFirst('gesto_', 'demo_');
      await db.update('gesto', {'clase_reconocimiento': old},
          where: 'clase_reconocimiento = ?', whereArgs: [g.recognitionClass]);
    }
    await db.rawUpdate("UPDATE intencion_comunicativa "
        "SET nombre = nombre || ' (DEMO)'");
    final picto = (await app.communication.buildBoard(profileId))
        .byCategory
        .values
        .expand((l) => l)
        .first;
    await db.insert('interaccion', {
      'fecha_hora': DateTime.now().toIso8601String(),
      'detalle': 'Gesto reconocido (DEMO — resultado simulado)',
      'id_pictograma': picto.id,
      'id_perfil': profileId,
    });
    await db.execute('PRAGMA user_version = 1');
    await app.db.close();

    final reopened = await _App.open(path);
    final rdb = reopened.db.db;
    final classes = (await rdb.query('gesto'))
        .map((r) => r['clase_reconocimiento'] as String)
        .toList();
    expect(classes.every((c) => c.startsWith('gesto_')), isTrue);
    final intents = (await rdb.query('intencion_comunicativa'))
        .map((r) => r['nombre'] as String);
    expect(intents.any((n) => n.contains('DEMO')), isFalse);
    final detail = (await rdb.query('interaccion')).single['detalle'];
    expect(detail, 'Gesto reconocido');
    expect((await reopened.profiles.byId(profileId))?.child.name,
        'Valentina López');
    await reopened.db.close();
  });

  test('Migración v5 → v6: agrega los gestos del modelo y los habilita',
      () async {
    final (app, _, profileId) = await withProfile();
    final db = app.db.db;
    final nuevos = kSeedGestures.skip(4).map((g) => g.recognitionClass);
    for (final c in nuevos) {
      final g = (await db.query('gesto',
              where: 'clase_reconocimiento = ?', whereArgs: [c]))
          .single['id_gesto'];
      final i = (await db.query('intencion_comunicativa',
              where: 'id_gesto = ?', whereArgs: [g]))
          .single['id_intencion'];
      await db.update('pictograma', {'id_intencion': null},
          where: 'id_intencion = ?', whereArgs: [i]);
      await db.delete('intencion_comunicativa',
          where: 'id_intencion = ?', whereArgs: [i]);
      await db.delete('gesto', where: 'id_gesto = ?', whereArgs: [g]);
    }
    final profile = (await app.profiles.byId(profileId))!;
    await SqliteChildProfileRepository(app.db).update(profile.copyWith(
        preferences: profile.preferences
            .copyWith(enabledGestureIds: const [1, 2, 3, 4])));
    await db.update('gesto', {
      'instrucciones': 'Levanta solo el dedo índice.\nDobla los otros dedos.\n'
          'Mantén el gesto quieto unos 3 segundos.'
    }, where: "clase_reconocimiento = 'gesto_ayuda'");
    await db.execute('PRAGMA user_version = 5');
    await app.db.close();

    final reopened = await _App.open(path);
    final rdb = reopened.db.db;
    final gestos = await rdb.query('gesto', orderBy: 'id_gesto');
    expect(gestos.map((g) => g['clase_reconocimiento']),
        kSeedGestures.map((g) => g.recognitionClass));
    for (final g in gestos.skip(4)) {
      final i = (await rdb.query('intencion_comunicativa',
              where: 'id_gesto = ?', whereArgs: [g['id_gesto']]))
          .single;
      expect(
          await rdb.query('pictograma',
              where: 'id_intencion = ?', whereArgs: [i['id_intencion']]),
          hasLength(1));
    }
    final ayuda = gestos.firstWhere(
        (g) => g['clase_reconocimiento'] == 'gesto_ayuda');
    expect(ayuda['representacion_visual'], '☝️');
    expect(ayuda['instrucciones'], contains('dedo índice'));
    expect(ayuda['instrucciones'], isNot(contains('quieto')));
    final prefs = (await reopened.profiles.byId(profileId))!.preferences;
    expect(prefs.enabledGestureIds,
        List.generate(kSeedGestures.length, (i) => i + 1));
    await reopened.db.close();

    final again = await _App.open(path);
    expect(await again.db.db.query('gesto'), hasLength(kSeedGestures.length));
    await again.db.close();
  });

  test('La categoría de un pictograma inicial es por perfil', () async {
    final (app, tutorId, luisId) = await withProfile();
    final ana = await app.profiles.create(
        tutorId, ProfileForm(name: 'Ana', birthDate: DateTime(2018, 2, 3)));
    Future<int> categoria(int perfil, int id) async =>
        (await app.communication.catalog(perfil))
            .firstWhere((i) => i.pictogram.id == id)
            .pictogram
            .categoryId;

    final item = (await app.communication.catalog(luisId))
        .firstWhere((i) => !i.pictogram.isCustom);
    final id = item.pictogram.id!;
    final original = item.pictogram.categoryId;
    final otra = (await app.communication.categories())
        .firstWhere((c) => c.id != original)
        .id;

    await app.communication.updatePictogram(item.pictogram,
        profileId: luisId, name: '', message: '', categoryId: otra);

    expect(await categoria(luisId, id), otra);
    expect(await categoria(ana.id!, id), original);
    final tablero = await app.communication.buildBoard(luisId);
    expect(tablero.byCategory[otra]!.where((p) => p.id == id), hasLength(1));
    expect(tablero.byCategory[original]!.where((p) => p.id == id), isEmpty);

    final perfil = (await app.profiles.byId(luisId))!;
    await SqliteChildProfileRepository(app.db).update(perfil.copyWith(
        preferences: const CommunicationPreferences(pictogramColumns: 2)));
    expect(await categoria(luisId, id), otra);

    await SqlitePictogramRepository(app.db)
        .setProfileCategory(luisId, id, original);
    final limpio = (await app.profiles.byId(luisId))!.preferences;
    expect(limpio.pictogramCategories, isEmpty);
    await app.db.close();
  });

  test('Mensaje y pictograma por gesto: por perfil y sin reescribir el historial',
      () async {
    final (app, tutorId, luisId) = await withProfile();
    final ana = await app.profiles.create(
        tutorId, ProfileForm(name: 'Ana', birthDate: DateTime(2018, 2, 3)));
    final recognizer = TestModeGestureRecognitionService();
    final service = GestureService(recognizer, SqliteGestureRepository(app.db),
        SqlitePictogramRepository(app.db));
    final si = (await service.catalog())
        .firstWhere((g) => g.recognitionClass == 'gesto_si');
    final frame = GestureSequence([
      GestureFrame(
          bytes: Uint8List(1), width: 1, height: 1, capturedAt: DateTime(2026))
    ]);

    Future<GestureOutcome> reconoce(int perfil) async {
      await service.ensureLoaded();
      recognizer.setTestOutcome('gesto_si');
      final out = await service.recognize(frame, [si], profileId: perfil);
      return out!;
    }

    await app.privacy.decide(luisId, granted: true);
    final antes = await reconoce(luisId);
    expect(antes.intention.message, 'Sí');
    await app.interactions.recordGesture(luisId,
        gesture: antes.gesture,
        intention: antes.intention,
        pictogram: antes.pictogram);

    final otro = (await app.communication.catalog(luisId))
        .map((i) => i.pictogram)
        .firstWhere((p) => p.id != antes.pictogram.id);
    await service.saveMessage(luisId, si,
        message: '  Estoy bien  ', pictogramId: otro.id);
    final despues = await reconoce(luisId);
    expect(despues.intention.message, 'Estoy bien');
    expect(despues.pictogram.id, otro.id);
    expect(despues.gesture.id, si.id);

    expect((await reconoce(ana.id!)).intention.message, 'Sí');

    await app.interactions.recordGesture(luisId,
        gesture: despues.gesture,
        intention: despues.intention,
        pictogram: despues.pictogram);
    final registros =
        await SqliteInteractionRepository(app.db).recordsForProfile(luisId);
    expect(registros.map((r) => r.message).toSet(), {'Sí', 'Estoy bien'});
    final viejo = registros.firstWhere((r) => r.message == 'Sí');
    expect(viejo.interaction.pictogramId, antes.pictogram.id);

    await app.db.db.update('interaccion', {'detalle': 'Gesto reconocido'},
        where: 'id_interaccion = ?', whereArgs: [viejo.interaction.id]);
    final legado = (await SqliteInteractionRepository(app.db)
            .recordsForProfile(luisId))
        .firstWhere((r) => r.interaction.id == viejo.interaction.id);
    expect(legado.message, legado.pictogramMessage);

    final perfil = (await app.profiles.byId(luisId))!;
    await SqliteChildProfileRepository(app.db).update(perfil.copyWith(
        preferences: const CommunicationPreferences(pictogramColumns: 2)));
    expect((await reconoce(luisId)).intention.message, 'Estoy bien');

    expect(service.saveMessage(luisId, si, message: '   ', pictogramId: null),
        throwsA(isA<DomainException>()));
    await service.resetMessage(luisId, si);
    expect((await reconoce(luisId)).intention.message, 'Sí');
    expect(
        (await app.profiles.byId(luisId))!.preferences.gestureCustomizations,
        isEmpty);
    await app.db.close();
  });

  test('Eliminar un pictograma asignado: el gesto vuelve al original', () async {
    final (app, _, luisId) = await withProfile();
    final recognizer = TestModeGestureRecognitionService();
    final service = GestureService(recognizer, SqliteGestureRepository(app.db),
        SqlitePictogramRepository(app.db));
    final si = (await service.catalog())
        .firstWhere((g) => g.recognitionClass == 'gesto_si');
    final original = (await service.messageFor(luisId, si))!.originalPictogram!;
    final cat = (await app.communication.categories()).first.id;
    final mio = await app.communication.addCustom(
        profileId: luisId,
        name: 'Mi foto',
        message: 'Estoy bien',
        categoryId: cat,
        image: Uint8List.fromList([1, 2, 3]));
    await service.saveMessage(luisId, si,
        message: 'Estoy bien', pictogramId: mio.id);
    expect(await app.communication.gesturesUsing(luisId, mio.id!), ['Sí']);

    expect(await app.communication.deleteCustom(mio.id!), isTrue);

    final ahora = (await service.messageFor(luisId, si))!;
    expect(ahora.pictogram!.id, original.id);
    expect(ahora.message, 'Estoy bien');
    await app.db.close();
  });

  test('Registro y login con correo; credenciales inválidas',
      () async {
    final app = await _App.open(path);
    expect(
        () => app.auth.register(const RegistrationForm(
            email: 'no-es-correo', password: 'x', passwordConfirm: 'x')),
        throwsA(isA<DomainException>()));
    await app.auth.register(const RegistrationForm(
        email: 'Maria@Email.com',
        password: 'secreta123',
        passwordConfirm: 'secreta123'));
    final acc = await app.auth.login('maria@email.com', 'secreta123');
    expect(acc.email.value, 'maria@email.com');
    expect(() => app.auth.login('maria@email.com', 'mala'),
        throwsA(isA<DomainException>()));
    expect(await app.auth.verifyPassword(acc.id!, 'secreta123'), isTrue);
    expect(await app.auth.verifyPassword(acc.id!, 'otra'), isFalse);
    await app.db.close();
  });

  test('Persistencia: perfil, pictograma, voz y consentimiento sobreviven '
      'al cerrar y reabrir', () async {
    final (app, tutorId, profileId) = await withProfile();
    final cats = await app.communication.categories();
    await app.communication.addCustom(
      profileId: profileId,
      name: 'Mi osito',
      message: 'Quiero mi osito',
      categoryId: cats.first.id,
      image: Uint8List.fromList([1, 2, 3, 4]),
    );
    final v = await app.voice.voiceFor(profileId);
    await app.voice.saveVoice(v.copyWith(rate: 0.6, volume: 0.75));
    await app.privacy.decide(profileId, granted: true);
    await app.db.close();

    final reopened = await _App.open(path);
    final profiles = await reopened.profiles.forTutor(tutorId);
    expect(profiles.single.child.name, 'Valentina López');
    final board = await reopened.communication.buildBoard(profileId);
    expect(board.pictogramCount, kSeedPictograms.length + 1);
    final catalog = await reopened.communication.catalog(profileId);
    final osito =
        catalog.firstWhere((c) => c.pictogram.name == 'Mi osito').pictogram;
    expect(osito.isCustom, isTrue);
    expect(osito.image, Uint8List.fromList([1, 2, 3, 4]));
    final voice = await reopened.voice.voiceFor(profileId);
    expect(voice.rate, 0.6);
    expect(voice.volume, 0.75);
    expect((await reopened.privacy.forProfile(profileId))!.state,
        ConsentState.granted);
    await reopened.db.close();
  });

  test('Pictograma personalizado exige imagen y mensaje', () async {
    final (app, _, profileId) = await withProfile();
    final cat = (await app.communication.categories()).first.id;
    expect(
        () => app.communication.addCustom(
            profileId: profileId,
            name: 'X',
            message: 'Hola',
            categoryId: cat,
            image: null),
        throwsA(isA<DomainException>()));
    expect(
        () => app.communication.addCustom(
            profileId: profileId,
            name: 'X',
            message: '  ',
            categoryId: cat,
            image: Uint8List.fromList([1])),
        throwsA(isA<DomainException>()));
    await app.db.close();
  });

  test('Ocultar quita del tablero sin borrar del catálogo', () async {
    final (app, _, profileId) = await withProfile();
    final catalog = await app.communication.catalog(profileId);
    final first = catalog.first.pictogram;
    await app.communication.setSelected(profileId, first.id!, false);
    final board = await app.communication.buildBoard(profileId);
    expect(board.pictogramCount, kSeedPictograms.length - 1);
    final after = await app.communication.catalog(profileId);
    expect(after.length, catalog.length);
    expect(after.firstWhere((c) => c.pictogram.id == first.id).selected,
        isFalse);
    await app.db.close();
  });

  test('D4: sin consentimiento vigente no se registran interacciones',
      () async {
    final (app, _, profileId) = await withProfile();
    final picto = (await app.communication.buildBoard(profileId))
        .byCategory
        .values
        .expand((l) => l)
        .first;
    expect(await app.interactions.recordPictogram(profileId, picto), isFalse);
    await app.privacy.decide(profileId, granted: true);
    expect(await app.interactions.recordPictogram(profileId, picto), isTrue);
    await app.privacy.withdraw(profileId);
    expect(await app.interactions.recordPictogram(profileId, picto), isFalse);
    final rows = await app.db.db.query('interaccion');
    expect(rows.length, 1);
    final c = await app.privacy.forProfile(profileId);
    expect(c!.state, ConsentState.withdrawn);
    expect(c.withdrawnAt, isNotNull);
    await app.db.close();
  });

  test('D5: eliminar perfil borra en cascada sus datos exclusivos', () async {
    final (app, tutorId, profileId) = await withProfile();
    final other = await app.profiles.create(
        tutorId, ProfileForm(name: 'Luis', birthDate: DateTime(2018, 1, 1)));
    final cat = (await app.communication.categories()).first.id;
    await app.communication.addCustom(
        profileId: profileId,
        name: 'Solo mío',
        message: 'Solo mío',
        categoryId: cat,
        image: Uint8List.fromList([9]));
    final shared = await app.communication.addCustom(
        profileId: profileId,
        name: 'Compartido',
        message: 'Compartido',
        categoryId: cat,
        image: Uint8List.fromList([8]));
    await app.communication.setSelected(other.id!, shared.id!, true);
    await app.privacy.decide(profileId, granted: true);
    await app.interactions.recordPictogram(profileId, shared);

    await app.profiles.delete(profileId);

    Future<int> count(String sql, [List<Object?>? a]) async =>
        Sqflite.firstIntValue(await app.db.db.rawQuery(sql, a))!;
    expect(await count('SELECT COUNT(*) FROM perfil_nino WHERE id_perfil=?',
        [profileId]), 0);
    expect(await count('SELECT COUNT(*) FROM interaccion'), 0);
    expect(await count('SELECT COUNT(*) FROM consentimiento'), 0);
    expect(await count('SELECT COUNT(*) FROM configuracion_voz'), 1);
    expect(await count('SELECT COUNT(*) FROM nino'), 1);
    expect(await count("SELECT COUNT(*) FROM pictograma WHERE nombre='Solo mío'"),
        0);
    expect(
        await count("SELECT COUNT(*) FROM pictograma WHERE nombre='Compartido'"),
        1);
    expect(await count('SELECT COUNT(*) FROM pictograma WHERE imagen IS NULL'),
        kSeedPictograms.length);
    await app.db.close();
  });

  test('Un pictograma propio solo aparece en el perfil que lo creó',
      () async {
    final (app, tutorId, profileId) = await withProfile();
    final sibling = await app.profiles.create(
        tutorId, ProfileForm(name: 'Luis', birthDate: DateTime(2018, 1, 1)));
    final otherTutor = await app.auth.register(const RegistrationForm(
        email: 'jose@email.com',
        password: 'secreta123',
        passwordConfirm: 'secreta123'));
    final stranger = await app.profiles.create(otherTutor.id!,
        ProfileForm(name: 'Ana', birthDate: DateTime(2017, 3, 3)));
    final cat = (await app.communication.categories()).first.id;
    final mine = await app.communication.addCustom(
        profileId: profileId,
        name: 'Mi osito',
        message: 'Quiero mi osito',
        categoryId: cat,
        image: Uint8List.fromList([7]));

    Future<bool> visibleIn(int id) async =>
        (await app.communication.catalog(id))
            .any((e) => e.pictogram.id == mine.id);
    expect(await visibleIn(profileId), isTrue);
    expect(await visibleIn(sibling.id!), isFalse);
    expect(await visibleIn(stranger.id!), isFalse);

    await app.communication.setSelected(profileId, mine.id!, false);
    expect(await visibleIn(profileId), isTrue);
    await app.profiles.delete(profileId);
    expect(
        (await app.db.db.query('pictograma',
                where: 'id_pictograma = ?', whereArgs: [mine.id]))
            .isEmpty,
        isTrue);
    await app.db.close();
  });

  test('Valores de voz fuera de rango se rechazan', () async {
    final (app, _, profileId) = await withProfile();
    final v = await app.voice.voiceFor(profileId);
    expect(() => app.voice.saveVoice(v.copyWith(rate: 2)),
        throwsA(isA<DomainException>()));
    expect(() => app.voice.saveVoice(v.copyWith(volume: 0)),
        throwsA(isA<DomainException>()));
    await app.db.close();
  });
}
