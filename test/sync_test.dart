import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/application/communication_service.dart';
import 'package:gestuvoz/application/interaction_service.dart';
import 'package:gestuvoz/application/privacy_service.dart';
import 'package:gestuvoz/application/profile_service.dart';
import 'package:gestuvoz/application/reporting_service.dart';
import 'package:gestuvoz/domain/auth.dart';
import 'package:gestuvoz/domain/child.dart';
import 'package:gestuvoz/infrastructure/persistence/database.dart';
import 'package:gestuvoz/infrastructure/persistence/report_exporter.dart';
import 'package:gestuvoz/infrastructure/persistence/repositories.dart';
import 'package:gestuvoz/infrastructure/remote/api_client.dart';
import 'package:gestuvoz/infrastructure/remote/remote_history_source.dart';
import 'package:gestuvoz/infrastructure/sync/sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeBackend {
  final requests = <http.Request>[];
  final getResponses = <String, Object?>{};
  final fileResponses = <String, List<int>>{};
  var _uploads = 0;
  bool offline = false;
  Completer<void>? gate;

  late final client = MockClient((request) async {
    if (offline) throw const SocketException('sin red');
    await gate?.future;
    requests.add(request);
    final path = request.url.path.replaceFirst('/api/v1/', '');
    switch (request.method) {
      case 'GET':
        if (fileResponses.containsKey(path)) {
          return http.Response.bytes(fileResponses[path]!, 200,
              headers: {'content-type': 'image/png'});
        }
        if (!getResponses.containsKey(path)) {
          return http.Response(
              jsonEncode({'error': {'codigo': 'no_encontrado'}}), 404);
        }
        return http.Response.bytes(
            utf8.encode(jsonEncode(getResponses[path])), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      case 'DELETE':
        return http.Response('', 204);
      case 'PUT' when path.endsWith('/imagen'):
        _uploads++;
        return http.Response(
            jsonEncode({'referencia_imagen': 'ref-$_uploads'}), 200);
      default:
        return http.Response(jsonEncode({'ok': true}), 200);
    }
  });

  List<String> get sent => [
        for (final r in requests)
          if (r.method != 'GET')
            '${r.method} ${r.url.path.replaceFirst('/api/v1/', '')}'
      ];

  Map<String, dynamic> bodyOf(String methodAndPath) {
    final r = requests.firstWhere((r) =>
        '${r.method} ${r.url.path.replaceFirst('/api/v1/', '')}' ==
        methodAndPath);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

class _Env {
  _Env(this.db, this.backend, this.tutorId)
      : profiles = ProfileService(
            SqliteChildProfileRepository(db), SqliteGestureRepository(db)),
        privacy = PrivacyService(SqliteConsentRepository(db)),
        communication = CommunicationService(SqlitePictogramRepository(db)),
        interactions = InteractionService(
            SqliteInteractionRepository(db), SqliteConsentRepository(db)),
        sync = SyncService(
          db,
          ApiClient(
            token: ({bool forceRefresh = false}) async => 'token',
            baseUrl: 'http://backend.test/api/v1/',
            client: backend.client,
          ),
        );

  final GestuVozDatabase db;
  final FakeBackend backend;
  final int tutorId;
  final ProfileService profiles;
  final PrivacyService privacy;
  final CommunicationService communication;
  final InteractionService interactions;
  final SyncService sync;

  static Future<_Env> open(String path, {FakeBackend? backend}) async {
    final db =
        await GestuVozDatabase.open(path: path, factory: databaseFactoryFfi);
    final account = await SqliteAuthRepository(db).linkRemote(
      uid: 'uid-tutor',
      email: Email('maria@email.com'),
      password: const SecretHash(hash: 'h', salt: 's'),
    );
    final env = _Env(db, backend ?? FakeBackend(), account.id!);
    env.sync.start(env.tutorId);
    await env.sync.stop();
    env.sync.start(env.tutorId);
    return env;
  }

  Future<int> count(String sql) async =>
      Sqflite.firstIntValue(await db.db.rawQuery(sql))!;
}

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late String path;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gestuvoz_sync_');
    path = '${tmp.path}/gestuvoz.db';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<int> newProfile(_Env env) async => (await env.profiles.create(
          env.tutorId,
          ProfileForm(
              name: 'Valentina López', birthDate: DateTime(2019, 5, 14))))
      .id!;

  test('La categoría por perfil se envía al backend', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    final item = (await env.communication.catalog(profileId))
        .firstWhere((i) => !i.pictogram.isCustom);
    final otra = (await env.communication.categories())
        .firstWhere((c) => c.id != item.pictogram.categoryId)
        .id;
    await env.sync.pushPending();
    env.backend.requests.clear();

    await env.communication.updatePictogram(item.pictogram,
        profileId: profileId, name: '', message: '', categoryId: otra);
    await env.sync.pushPending();

    final uuid = (await env.db.db.query('perfil_nino')).first['uuid'];
    final prefs =
        env.backend.bodyOf('PUT perfiles/$uuid')['preferencias_de_comunicacion'];
    expect(prefs['categorias_pictogramas'],
        {'base-${item.pictogram.id}': otra});

    await SqliteGestureRepository(env.db).setCustomization(
        profileId,
        2,
        GestureCustomization(
            message: 'Tengo sed', pictogramId: item.pictogram.id));
    await env.sync.pushPending();
    final body = env.backend.requests.lastWhere(
        (r) => r.method == 'PUT' && r.url.path.endsWith('perfiles/$uuid'));
    expect(
        (jsonDecode(body.body) as Map)['preferencias_de_comunicacion']
            ['gestos_personalizados'],
        {
          'gesto-2': {
            'mensaje': 'Tengo sed',
            'id_pictograma': 'base-${item.pictogram.id}',
          }
        });
    await env.sync.stop();
    await env.db.close();
  });

  test('Quien consulta durante una subida espera a que termine', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    await env.sync.pushPending();
    final picto = (await env.communication.catalog(profileId)).first.pictogram;
    await env.interactions.recordPictogram(profileId, picto);

    final gate = Completer<void>();
    env.backend.gate = gate;
    final first = env.sync.pushPending();
    var joined = false;
    final second = env.sync.pushPending().then((_) => joined = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(joined, isFalse);

    gate.complete();
    await first;
    await second;
    expect(await env.count(
        'SELECT COUNT(*) FROM interaccion WHERE sincronizada = 0'), 0);
    await env.sync.stop();
    await env.db.close();
  });

  test('El resumen de hoy usa el servidor y sin red usa el dispositivo',
      () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    await env.sync.pushPending();
    final picto = (await env.communication.catalog(profileId)).first.pictogram;
    await env.interactions.recordPictogram(profileId, picto);
    await env.sync.pushPending();
    final uuid = (await env.db.db.query('perfil_nino')).first['uuid'];
    env.backend.getResponses['perfiles/$uuid/reportes'] = {
      'total_interacciones': 13,
      'interacciones_por_gesto': 5,
      'interacciones_por_pictograma': 8,
      'intenciones_distintas': 2,
      'actividad_semanal': [],
      'mas_frecuentes': [],
    };
    final reporting = ReportingService(
      SqliteInteractionRepository(env.db),
      FileReportExporter(),
      history: RemoteHistorySource(
        env.db,
        ApiClient(
          token: ({bool forceRefresh = false}) async => 'token',
          baseUrl: 'http://backend.test/api/v1/',
          client: env.backend.client,
        ),
      ),
    );

    final remote = await reporting.todaySummary(profileId);
    expect(remote.totalInteractions, 13);
    expect(remote.gestureInteractions, 5);

    env.backend.offline = true;
    final local = await reporting.todaySummary(profileId);
    expect(local.totalInteractions, 1);

    env.backend.offline = false;
    env.backend.getResponses['perfiles/$uuid/reportes'] = {
      'total_interacciones': 0,
      'interacciones_por_gesto': 0,
      'interacciones_por_pictograma': 0,
      'intenciones_distintas': 0,
      'actividad_semanal': [],
      'mas_frecuentes': [],
    };
    final behind = await reporting.todaySummary(profileId);
    expect(behind.totalInteractions, 1);
    await env.sync.stop();
    await env.db.close();
  });

  test('Sin conexión no se pierde nada y se informa', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    env.backend.offline = true;
    expect(await env.sync.pushPending(), isFalse);
    expect(env.sync.status.value.online, isFalse);
    expect(await env.count('SELECT COUNT(*) FROM sync_pendiente'), 3);
    env.backend.offline = false;
    expect(await env.sync.pushPending(), isTrue);
    expect(await env.count('SELECT COUNT(*) FROM sync_pendiente'), 0);
    await env.sync.stop();
    await env.db.close();
  });

  test('Sin consentimiento no se envían datos del niño', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: false);
    await env.sync.pushPending();
    expect(env.backend.sent.length, 1);
    expect(env.backend.sent.single, endsWith('/consentimiento'));
    expect(await env.count('SELECT COUNT(*) FROM sync_pendiente'), 2);
    await env.sync.stop();
    await env.db.close();
  });

  test('Orden de envío, formato de datos e interacciones', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    final picto = (await env.communication.buildBoard(profileId))
        .byCategory
        .values
        .expand((l) => l)
        .first;
    await env.interactions.recordPictogram(profileId, picto);
    await env.sync.pushPending();

    final uuid = (await env.db.db.query('perfil_nino')).first['uuid'];
    expect(env.backend.sent, [
      'PUT perfiles/$uuid/consentimiento',
      'PUT perfiles/$uuid',
      'PUT perfiles/$uuid/configuracion-voz',
      'POST perfiles/$uuid/interacciones',
    ]);
    final perfil = env.backend.bodyOf('PUT perfiles/$uuid');
    expect(perfil['nino']['fecha_nacimiento'], '2019-05-14');
    final prefs = perfil['preferencias_de_comunicacion'];
    expect((prefs['gestos_habilitados'] as List).first, 'gesto-1');
    expect((prefs['pictogramas'] as List).first['id_pictograma'], 'base-1');
    final lote = env.backend.bodyOf('POST perfiles/$uuid/interacciones');
    expect((lote['interacciones'] as List).single['id_pictograma'],
        'base-${picto.id}');
    expect(await env.count(
        'SELECT COUNT(*) FROM interaccion WHERE sincronizada = 0'), 0);
    await env.sync.stop();
    await env.db.close();
  });

  test('Eliminar un perfil se envía al backend', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    await env.sync.pushPending();
    final uuid = (await env.db.db.query('perfil_nino')).first['uuid'];
    await env.profiles.delete(profileId);
    await env.sync.pushPending();
    expect(env.backend.sent.last, 'DELETE perfiles/$uuid');
    await env.sync.stop();
    await env.db.close();
  });

  test('Teléfono nuevo: la descarga restaura perfil, niño y ajustes',
      () async {
    final backend = FakeBackend()
      ..getResponses.addAll({
        'pictogramas': [
          {
            'id_pictograma': 'p-osito',
            'nombre': 'Mi osito',
            'mensaje': 'Quiero mi osito',
            'id_categoria': 2,
            'referencia_imagen': null,
            'actualizado_en': '2026-10-10T10:00:00+00:00',
          }
        ],
        'perfiles': [
          {
            'id_perfil': 'perfil-1',
            'nivel_apoyo': 'Moderado',
            'estado_perfil': 'activo',
            'id_nino': 'nino-1',
            'actualizado_en': '2026-10-10T10:00:00+00:00',
            'preferencias_de_comunicacion': {
              'gestos_activados': true,
              'gestos_habilitados': ['gesto-2'],
              'columnas_tablero': 2,
              'alto_contraste': false,
              'categorias_pictogramas': {'base-5': 3},
              'gestos_personalizados': {
                'gesto-2': {'mensaje': 'Tengo sed', 'id_pictograma': 'base-5'},
              },
              'pictogramas': [
                {'id_pictograma': 'p-osito', 'orden': 1},
                {'id_pictograma': 'base-5', 'orden': 2},
              ],
            },
            'nino': {
              'id_nino': 'nino-1',
              'nombre': 'Luis',
              'fecha_nacimiento': '2018-03-02',
              'genero': null,
            },
          }
        ],
        'perfiles/perfil-1/consentimiento': {
          'estado_consentimiento': 'otorgado',
          'fecha_registro': '2026-10-10T10:00:00+00:00',
          'fecha_retiro': null,
          'actualizado_en': '2026-10-10T10:00:00+00:00',
        },
        'perfiles/perfil-1/configuracion-voz': {
          'idioma': 'es-ES',
          'tipo_voz': null,
          'velocidad': 0.6,
          'volumen': 0.8,
          'voz_activada': true,
          'actualizado_en': '2026-10-10T10:00:00+00:00',
        },
      });
    final env = await _Env.open(path, backend: backend);
    await env.sync.pullAll(env.tutorId);

    final profiles = await env.profiles.forTutor(env.tutorId);
    expect(profiles.single.child.name, 'Luis');
    expect(profiles.single.preferences.pictogramColumns, 2);
    expect(profiles.single.preferences.enabledGestureIds, [2]);
    final board = await env.communication.buildBoard(profiles.single.id!);
    expect(board.pictogramCount, 2);
    final custom = profiles.single.preferences.gestureCustomizations[2]!;
    expect(custom.message, 'Tengo sed');
    expect(custom.pictogramId, 5);
    expect(board.byCategory[3]!.where((p) => p.id == 5), hasLength(1));
    expect((await env.privacy.forProfile(profiles.single.id!))!
        .allowsProcessing, isTrue);
    final voz = await env.db.db.query('configuracion_voz');
    expect(voz.single['velocidad'], 0.6);
    expect(await env.count('SELECT COUNT(*) FROM sync_pendiente'), 0);
    await env.sync.stop();
    await env.db.close();
  });

  test('Historial y reportes desde el backend', () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    await env.sync.pushPending();
    final uuid = (await env.db.db.query('perfil_nino')).first['uuid'];
    final gesture = (await env.db.db.query('gesto', limit: 1)).first;
    final gestureId = gesture['id_gesto'] as int;
    env.backend.getResponses.addAll({
      'perfiles/$uuid/interacciones': [
        {
          'id_interaccion': 'i-1',
          'fecha_hora': '2026-10-15T15:00:00+00:00',
          'detalle': null,
          'id_pictograma': 'base-1',
          'id_gesto': 'gesto-$gestureId',
          'id_intencion': null,
        },
        {
          'id_interaccion': 'i-2',
          'fecha_hora': '2026-10-15T14:00:00+00:00',
          'detalle': null,
          'id_pictograma': 'no-existe',
          'id_gesto': null,
          'id_intencion': null,
        },
      ],
      'perfiles/$uuid/reportes': {
        'total_interacciones': 2,
        'interacciones_por_gesto': 1,
        'interacciones_por_pictograma': 1,
        'intenciones_distintas': 0,
        'actividad_semanal': [
          for (var d = 0; d < 7; d++) {'fecha': '', 'cantidad': d == 5 ? 2 : 0}
        ],
        'datos_suficientes_para_frecuencias': false,
        'mas_frecuentes': [],
      },
    });
    final history = RemoteHistorySource(
      env.db,
      ApiClient(
        token: ({bool forceRefresh = false}) async => 'token',
        baseUrl: 'http://backend.test/api/v1/',
        client: env.backend.client,
      ),
    );
    final records = await history.records(profileId,
        from: DateTime(2026, 10, 9), to: DateTime(2026, 10, 16));
    final query = env.backend.requests.last.url.queryParameters;
    expect(query, {'desde': '2026-10-09', 'hasta': '2026-10-15'});
    expect(records.length, 2);
    expect(records.first.pictogramName,
        (await env.db.db.query('pictograma', where: 'id_pictograma = 1'))
            .first['nombre']);
    expect(records.first.gestureName, gesture['nombre']);
    expect(records.last.pictogramName, 'Pictograma eliminado');

    final summary = await history.summary(profileId);
    expect(summary.totalInteractions, 2);
    expect(summary.weekly[5], 2);

    expect(await history.detail(profileId, records.first), isNull);

    env.backend.offline = true;
    await expectLater(history.records(profileId),
        throwsA(isA<DomainException>()));
    await env.sync.stop();
    await env.db.close();
  });

  test('Las imágenes de los pictogramas propios se suben a Cloud Storage',
      () async {
    final env = await _Env.open(path);
    final profileId = await newProfile(env);
    await env.privacy.decide(profileId, granted: true);
    final image = Uint8List.fromList(List.generate(64, (i) => i));
    final picto = await env.communication.addCustom(
        profileId: profileId,
        name: 'Mi osito',
        message: 'Quiero mi osito',
        categoryId: 2,
        image: image);
    await env.sync.pushPending();

    final uuid = (await env.db.db.query('pictograma',
            where: 'id_pictograma = ?', whereArgs: [picto.id]))
        .first['uuid'];
    expect(env.backend.sent,
        containsAllInOrder(['PUT pictogramas/$uuid', 'PUT pictogramas/$uuid/imagen']));
    final upload = env.backend.requests
        .lastWhere((r) => r.url.path.endsWith('/imagen'));
    expect(upload.bodyBytes, image);
    expect(upload.url.queryParameters['id_perfil'], isNotNull);
    Future<Object?> ref() async => (await env.db.db.query('pictograma',
            where: 'id_pictograma = ?', whereArgs: [picto.id]))
        .first['imagen_ref'];
    expect(await ref(), 'ref-1');

    final stored = (await env.communication.catalog(profileId))
        .map((e) => e.pictogram)
        .firstWhere((p) => p.id == picto.id);
    await env.communication.updatePictogram(stored,
        profileId: profileId,
        name: 'Mi osito',
        message: 'Dame mi osito',
        categoryId: 2,
        image: image);
    await env.sync.pushPending();
    expect(env.backend.sent.where((s) => s.endsWith('/imagen')).length, 1);

    await env.communication.updatePictogram(stored,
        profileId: profileId,
        name: 'Mi osito',
        message: 'Dame mi osito',
        categoryId: 2,
        image: Uint8List.fromList([9, 9, 9]));
    await env.sync.pushPending();
    expect(env.backend.sent.where((s) => s.endsWith('/imagen')).length, 2);
    expect(await ref(), 'ref-2');
    await env.sync.stop();
    await env.db.close();
  });

  test('Teléfono nuevo: la descarga trae las imágenes de los pictogramas',
      () async {
    final backend = FakeBackend()
      ..getResponses.addAll({
        'pictogramas': [
          {
            'id_pictograma': 'p-osito',
            'nombre': 'Mi osito',
            'mensaje': 'Quiero mi osito',
            'id_categoria': 2,
            'referencia_imagen': 'pictogramas/uid-tutor/p-osito/abc',
            'actualizado_en': '2026-10-10T10:00:00+00:00',
          }
        ],
        'perfiles': [],
      })
      ..fileResponses['pictogramas/p-osito/imagen'] = [1, 2, 3];
    final env = await _Env.open(path, backend: backend);
    await env.sync.pullAll(env.tutorId);
    final row = (await env.db.db
            .query('pictograma', where: 'uuid = ?', whereArgs: ['p-osito']))
        .first;
    expect(row['imagen'], [1, 2, 3]);
    expect(row['imagen_ref'], 'pictogramas/uid-tutor/p-osito/abc');
    backend.requests.clear();
    await env.sync.pullAll(env.tutorId);
    expect(
        backend.requests.where((r) => r.url.path.endsWith('/imagen')), isEmpty);
    await env.sync.stop();
    await env.db.close();
  });
}
