import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum RecognitionEventType {
  detected('detectado'),
  notRecognized('no_reconocido'),
  confirmedByTutor('confirmado_tutor'),
  rejectedByTutor('rechazado_tutor'),
  spokenAutomatically('dicho_automatico');

  const RecognitionEventType(this.code);
  final String code;

  static RecognitionEventType fromCode(String code) =>
      values.firstWhere((t) => t.code == code);
}

class RecognitionEvent {
  final int? id;
  final DateTime at;
  final String session;
  final int profileId;
  final RecognitionEventType type;
  final String? gesture;
  final double? confidence;
  final int? responseMs;
  final double? meanFrameMs;
  final int? maxFrameMs;
  final int? frames;

  const RecognitionEvent({
    this.id,
    required this.at,
    required this.session,
    required this.profileId,
    required this.type,
    this.gesture,
    this.confidence,
    this.responseMs,
    this.meanFrameMs,
    this.maxFrameMs,
    this.frames,
  });

  Map<String, Object?> toRow() => {
        'fecha_hora': at.toIso8601String(),
        'sesion': session,
        'id_perfil': profileId,
        'tipo': type.code,
        'gesto': gesture,
        'confianza': confidence,
        'tiempo_respuesta_ms': responseMs,
        'latencia_media_ms': meanFrameMs,
        'latencia_max_ms': maxFrameMs,
        'fotogramas': frames,
      };

  static RecognitionEvent fromRow(Map<String, Object?> r) => RecognitionEvent(
        id: r['id_evento'] as int?,
        at: DateTime.parse(r['fecha_hora'] as String),
        session: r['sesion'] as String,
        profileId: r['id_perfil'] as int,
        type: RecognitionEventType.fromCode(r['tipo'] as String),
        gesture: r['gesto'] as String?,
        confidence: (r['confianza'] as num?)?.toDouble(),
        responseMs: r['tiempo_respuesta_ms'] as int?,
        meanFrameMs: (r['latencia_media_ms'] as num?)?.toDouble(),
        maxFrameMs: r['latencia_max_ms'] as int?,
        frames: r['fotogramas'] as int?,
      );
}

class GestureMetrics {
  final String gesture;
  final int detected;
  final int confirmed;
  final int rejected;
  final double meanConfidence;

  const GestureMetrics({
    required this.gesture,
    required this.detected,
    required this.confirmed,
    required this.rejected,
    required this.meanConfidence,
  });
}

class MetricsSummary {
  final int attempts;
  final int detected;
  final int notRecognized;
  final int confirmedByTutor;
  final int rejectedByTutor;
  final int spokenAutomatically;
  final double? meanFrameMs;
  final int? maxFrameMs;
  final double? meanResponseMs;
  final List<GestureMetrics> byGesture;

  const MetricsSummary({
    required this.attempts,
    required this.detected,
    required this.notRecognized,
    required this.confirmedByTutor,
    required this.rejectedByTutor,
    required this.spokenAutomatically,
    required this.meanFrameMs,
    required this.maxFrameMs,
    required this.meanResponseMs,
    required this.byGesture,
  });

  double ratio(int value) => attempts == 0 ? 0 : value / attempts;

  static MetricsSummary of(List<RecognitionEvent> events) {
    int count(RecognitionEventType t) => events.where((e) => e.type == t).length;
    final attempts = events
        .where((e) =>
            e.type == RecognitionEventType.detected ||
            e.type == RecognitionEventType.notRecognized)
        .toList();
    final latencies = [
      for (final e in attempts)
        if (e.meanFrameMs != null && (e.frames ?? 0) > 0) e
    ];
    final totalFrames = latencies.fold<int>(0, (s, e) => s + e.frames!);
    final meanFrame = totalFrames == 0
        ? null
        : latencies.fold<double>(0, (s, e) => s + e.meanFrameMs! * e.frames!) /
            totalFrames;
    final maxes = [
      for (final e in attempts)
        if (e.maxFrameMs != null) e.maxFrameMs!
    ];
    final responses = [
      for (final e in events)
        if (e.type == RecognitionEventType.detected && e.responseMs != null)
          e.responseMs!
    ];
    final names = <String>{
      for (final e in events)
        if (e.gesture != null) e.gesture!
    }.toList()
      ..sort();
    final byGesture = [
      for (final g in names)
        () {
          final detected = events
              .where((e) =>
                  e.gesture == g && e.type == RecognitionEventType.detected)
              .toList();
          final conf = [
            for (final e in detected)
              if (e.confidence != null) e.confidence!
          ];
          return GestureMetrics(
            gesture: g,
            detected: detected.length,
            confirmed: events
                .where((e) =>
                    e.gesture == g &&
                    e.type == RecognitionEventType.confirmedByTutor)
                .length,
            rejected: events
                .where((e) =>
                    e.gesture == g &&
                    e.type == RecognitionEventType.rejectedByTutor)
                .length,
            meanConfidence:
                conf.isEmpty ? 0 : conf.reduce((a, b) => a + b) / conf.length,
          );
        }()
    ];
    return MetricsSummary(
      attempts: attempts.length,
      detected: count(RecognitionEventType.detected),
      notRecognized: count(RecognitionEventType.notRecognized),
      confirmedByTutor: count(RecognitionEventType.confirmedByTutor),
      rejectedByTutor: count(RecognitionEventType.rejectedByTutor),
      spokenAutomatically: count(RecognitionEventType.spokenAutomatically),
      meanFrameMs: meanFrame,
      maxFrameMs: maxes.isEmpty ? null : maxes.reduce((a, b) => a > b ? a : b),
      meanResponseMs: responses.isEmpty
          ? null
          : responses.reduce((a, b) => a + b) / responses.length,
      byGesture: byGesture,
    );
  }
}

class RecognitionMetricsStore {
  RecognitionMetricsStore._(this._db);
  final Database _db;

  static const fileName = 'gestuvoz_metricas.db';
  static const defaultSession = 'Sin nombre';

  static Future<RecognitionMetricsStore> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE evento_reconocimiento (
              id_evento            INTEGER PRIMARY KEY AUTOINCREMENT,
              fecha_hora           TEXT NOT NULL,
              sesion               TEXT NOT NULL,
              id_perfil            INTEGER NOT NULL,
              tipo                 TEXT NOT NULL,
              gesto                TEXT,
              confianza            REAL,
              tiempo_respuesta_ms  INTEGER,
              latencia_media_ms    REAL,
              latencia_max_ms      INTEGER,
              fotogramas           INTEGER
            )''');
          await db.execute('''
            CREATE TABLE ajuste (
              clave  TEXT PRIMARY KEY,
              valor  TEXT NOT NULL
            )''');
        },
      ),
    );
    return RecognitionMetricsStore._(db);
  }

  Future<void> close() => _db.close();

  Future<String> currentSession() async {
    final rows = await _db.query('ajuste',
        where: 'clave = ?', whereArgs: ['sesion_actual']);
    return rows.isEmpty ? defaultSession : rows.first['valor'] as String;
  }

  Future<void> setCurrentSession(String name) async {
    final value = name.trim().isEmpty ? defaultSession : name.trim();
    await _db.insert('ajuste', {'clave': 'sesion_actual', 'valor': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> record(RecognitionEvent event) async {
    await _db.insert('evento_reconocimiento', event.toRow());
  }

  Future<List<RecognitionEvent>> events({String? session}) async {
    final rows = await _db.query('evento_reconocimiento',
        where: session == null ? null : 'sesion = ?',
        whereArgs: session == null ? null : [session],
        orderBy: 'id_evento');
    return rows.map(RecognitionEvent.fromRow).toList();
  }

  Future<List<String>> sessions() async {
    final rows = await _db.rawQuery(
        'SELECT sesion FROM evento_reconocimiento GROUP BY sesion '
        'ORDER BY MIN(id_evento)');
    return [for (final r in rows) r['sesion'] as String];
  }

  Future<void> clear({String? session}) async {
    await _db.delete('evento_reconocimiento',
        where: session == null ? null : 'sesion = ?',
        whereArgs: session == null ? null : [session]);
  }

  static String toCsv(List<RecognitionEvent> events) {
    String cell(Object? v) {
      if (v == null) return '';
      final s = v is double ? v.toStringAsFixed(3) : v.toString();
      return s.contains(RegExp(r'[",;\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final header = [
      'id',
      'fecha_hora',
      'sesion',
      'id_perfil',
      'tipo',
      'gesto',
      'confianza',
      'tiempo_respuesta_ms',
      'latencia_media_ms',
      'latencia_max_ms',
      'fotogramas',
    ];
    final lines = [
      header.join(','),
      for (final e in events)
        [
          e.id,
          e.at.toIso8601String(),
          e.session,
          e.profileId,
          e.type.code,
          e.gesture,
          e.confidence,
          e.responseMs,
          e.meanFrameMs,
          e.maxFrameMs,
          e.frames,
        ].map(cell).join(','),
    ];
    return '﻿${lines.join('\n')}\n';
  }

  Future<String> exportCsv({String? session}) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'metricas_gestuvoz_$stamp.csv'));
    await file.writeAsString(toCsv(await events(session: session)));
    return file.path;
  }
}
