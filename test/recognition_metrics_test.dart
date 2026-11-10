import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/infrastructure/metrics/recognition_metrics.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RecognitionEvent _event(
  RecognitionEventType type, {
  String session = 'Prueba',
  String? gesture,
  double? confidence,
  int? responseMs,
  double? meanFrameMs,
  int? maxFrameMs,
  int? frames,
}) =>
    RecognitionEvent(
      at: DateTime(2026, 11, 10, 10),
      session: session,
      profileId: 1,
      type: type,
      gesture: gesture,
      confidence: confidence,
      responseMs: responseMs,
      meanFrameMs: meanFrameMs,
      maxFrameMs: maxFrameMs,
      frames: frames,
    );

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late RecognitionMetricsStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('metricas');
    store = await RecognitionMetricsStore.open(
        path: '${dir.path}/m.db', factory: databaseFactoryFfi);
  });

  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('El resumen calcula proporciones, latencias y totales por gesto', () {
    final s = MetricsSummary.of([
      _event(RecognitionEventType.detected,
          gesture: 'agua',
          confidence: 0.98,
          responseMs: 1200,
          meanFrameMs: 40,
          maxFrameMs: 60,
          frames: 10),
      _event(RecognitionEventType.confirmedByTutor, gesture: 'agua'),
      _event(RecognitionEventType.detected,
          gesture: 'hola',
          confidence: 0.96,
          responseMs: 800,
          meanFrameMs: 50,
          maxFrameMs: 90,
          frames: 10),
      _event(RecognitionEventType.rejectedByTutor, gesture: 'hola'),
      _event(RecognitionEventType.notRecognized,
          responseMs: 10000, meanFrameMs: 45, maxFrameMs: 70, frames: 20),
      _event(RecognitionEventType.notRecognized,
          responseMs: 10000, meanFrameMs: 45, maxFrameMs: 70, frames: 20),
    ]);
    expect(s.attempts, 4);
    expect(s.detected, 2);
    expect(s.notRecognized, 2);
    expect(s.ratio(s.detected), 0.5);
    expect(s.confirmedByTutor, 1);
    expect(s.rejectedByTutor, 1);
    expect(s.maxFrameMs, 90);
    expect(s.meanFrameMs, closeTo(45, 1e-9));
    expect(s.meanResponseMs, 1000);
    expect(s.byGesture.map((g) => g.gesture), ['agua', 'hola']);
    expect(s.byGesture.last.rejected, 1);
  });

  test('El resumen sin registros no divide entre cero', () {
    final s = MetricsSummary.of(const []);
    expect(s.attempts, 0);
    expect(s.ratio(s.detected), 0);
    expect(s.meanFrameMs, isNull);
  });

  test('Los eventos se guardan con la sesión actual y se filtran por sesión',
      () async {
    expect(await store.currentSession(), RecognitionMetricsStore.defaultSession);
    await store.setCurrentSession('  Participante 01  ');
    expect(await store.currentSession(), 'Participante 01');
    await store.record(_event(RecognitionEventType.detected,
        session: 'Participante 01', gesture: 'si', confidence: 0.97));
    await store.record(
        _event(RecognitionEventType.notRecognized, session: 'Participante 02'));
    expect(await store.sessions(), ['Participante 01', 'Participante 02']);
    final first = await store.events(session: 'Participante 01');
    expect(first.single.gesture, 'si');
    expect(first.single.confidence, closeTo(0.97, 1e-9));
    await store.clear(session: 'Participante 01');
    expect(await store.sessions(), ['Participante 02']);
    await store.clear();
    expect(await store.events(), isEmpty);
  });

  test('El CSV incluye la cabecera y escapa los textos con comas', () {
    final csv = RecognitionMetricsStore.toCsv([
      _event(RecognitionEventType.detected,
          session: 'Luz natural, sala',
          gesture: 'agua',
          confidence: 0.981,
          responseMs: 900,
          meanFrameMs: 41.5,
          maxFrameMs: 70,
          frames: 12),
    ]);
    final lines = csv.replaceFirst('﻿', '').trim().split('\n');
    expect(lines.first.split(',').first, 'id');
    expect(lines.first, contains('latencia_media_ms'));
    expect(lines.last, contains('"Luz natural, sala"'));
    expect(lines.last, contains('detectado'));
    expect(lines.last, contains('0.981'));
  });
}
