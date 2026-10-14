import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/application/auth_service.dart';
import 'package:gestuvoz/application/communication_service.dart';
import 'package:gestuvoz/application/interaction_service.dart';
import 'package:gestuvoz/application/privacy_service.dart';
import 'package:gestuvoz/application/profile_service.dart';
import 'package:gestuvoz/application/settings_service.dart';
import 'package:gestuvoz/domain/auth.dart';
import 'package:gestuvoz/domain/consent.dart';
import 'package:gestuvoz/infrastructure/persistence/database.dart';
import 'package:gestuvoz/infrastructure/persistence/repositories.dart';
import 'package:gestuvoz/infrastructure/security/secret_hasher_impl.dart';
import 'package:gestuvoz/infrastructure/seed/gesture_seed.dart';
import 'package:gestuvoz/infrastructure/seed/pictogram_seed.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Servicios reales sobre una base SQLite real (archivo temporal).
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
    expect(gestures.every((g) => g['instrucciones'] == null), isTrue);
    await app.db.close();
  });

  test('Migración v1 → v2: limpia etiquetas de prueba sin perder datos',
      () async {
    final (app, _, profileId) = await withProfile();
    final db = app.db.db;
    // Base como la creaba v1: clases demo_* y textos con "(DEMO)".
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
    // El perfil del usuario sigue ahí.
    expect((await reopened.profiles.byId(profileId))?.child.name,
        'Valentina López');
    await reopened.db.close();
  });

  test('HU018/HU019: registro y login con correo; credenciales inválidas',
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

  test('HU012: pictograma personalizado exige imagen y mensaje', () async {
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

  test('HU015: ocultar quita del tablero sin borrar del catálogo', () async {
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
    // El retiro no borra los datos existentes.
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

  test('HU017: valores de voz fuera de rango se rechazan', () async {
    final (app, _, profileId) = await withProfile();
    final v = await app.voice.voiceFor(profileId);
    expect(() => app.voice.saveVoice(v.copyWith(rate: 2)),
        throwsA(isA<DomainException>()));
    expect(() => app.voice.saveVoice(v.copyWith(volume: 0)),
        throwsA(isA<DomainException>()));
    await app.db.close();
  });
}
