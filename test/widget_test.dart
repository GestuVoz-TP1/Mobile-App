import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/domain/auth.dart';
import 'package:gestuvoz/domain/child.dart';
import 'package:gestuvoz/domain/communication.dart';
import 'package:gestuvoz/domain/gesture.dart';
import 'package:gestuvoz/domain/interaction.dart';
import 'package:gestuvoz/domain/ml.dart';
import 'package:gestuvoz/domain/reporting.dart';
import 'package:gestuvoz/infrastructure/ml/test_mode_gesture_recognition_service.dart';
import 'package:gestuvoz/presentation/theme.dart';
import 'package:gestuvoz/presentation/widgets/common.dart';
import 'package:gestuvoz/presentation/widgets/picto_tile.dart';

void main() {
  group('Value objects y entidades de dominio', () {
    test('Email normaliza y valida (HU018)', () {
      expect(Email('  Maria@Email.COM ').value, 'maria@email.com');
      expect(() => Email(''), throwsA(isA<DomainException>()));
      expect(() => Email('sin-arroba'), throwsA(isA<DomainException>()));
    });

    test('Child.create valida nombre, fecha y edad (HU021)', () {
      final now = DateTime(2026, 10, 7);
      expect(
          () => Child.create(name: '', birthDate: DateTime(2019), now: now),
          throwsA(isA<DomainException>()));
      expect(() => Child.create(name: 'Leo', birthDate: null, now: now),
          throwsA(isA<DomainException>()));
      expect(
          () => Child.create(
              name: 'Leo', birthDate: DateTime(2026, 1, 1), now: now),
          throwsA(isA<DomainException>()));
      final c = Child.create(
          name: 'Valentina López', birthDate: DateTime(2019, 5, 14), now: now);
      expect(Child.ageAt(c.birthDate, now), 7);
      expect(c.initials, 'VL');
    });

    test('Preferencias: JSON ida y vuelta y tamaños permitidos (HU016)', () {
      const p = CommunicationPreferences(
          gesturesEnabled: true, enabledGestureIds: [1, 3], pictogramColumns: 2);
      final back = CommunicationPreferences.fromJson(p.toJson());
      expect(back.gesturesEnabled, isTrue);
      expect(back.enabledGestureIds, [1, 3]);
      expect(back.pictogramColumns, 2);
      expect(() => p.copyWith(pictogramColumns: 7),
          throwsA(isA<DomainException>()));
    });

    test('Pictograma personalizado exige imagen y mensaje (HU012)', () {
      expect(
          () => Pictogram.custom(
              name: 'x', message: 'Hola', categoryId: 1, image: null),
          throwsA(isA<DomainException>()));
      final p = Pictogram.custom(
          name: '',
          message: 'Quiero mi osito',
          categoryId: 1,
          image: Uint8List.fromList([1]));
      expect(p.isCustom, isTrue);
      expect(p.name, 'Quiero mi osito');
    });

    test('Instrucciones del gesto por pasos', () {
      const g = Gesture(
          id: 1,
          name: 'Hola',
          recognitionClass: 'gesto_hola',
          availability: 'disponible',
          instructions: '  Levanta tu mano \n\n Muévela ');
      expect(g.hasInstructions, isTrue);
      expect(g.instructionSteps, ['Levanta tu mano', 'Muévela']);
    });
  });

  group('Reconocedor de prueba (sin porcentajes inventados)', () {
    const seq = GestureSequence([]);
    final frame = GestureSequence([
      GestureFrame(
          bytes: Uint8List(4), width: 2, height: 2, capturedAt: DateTime(2026))
    ]);

    test('No es un modelo real', () {
      expect(TestModeGestureRecognitionService().info.isRealModel, isFalse);
    });

    test('Sin resultado elegido no reconoce nada', () async {
      final m = TestModeGestureRecognitionService();
      expect((await m.recognize(frame, candidateClasses: ['gesto_agua']))
          .recognized, isFalse);
    });

    test('Devuelve el resultado elegido y nunca una confianza', () async {
      final m = TestModeGestureRecognitionService()
        ..setTestOutcome('gesto_agua');
      final r = await m.recognize(frame, candidateClasses: ['gesto_agua']);
      expect(r.recognitionClass, 'gesto_agua');
      expect(r.confidence, isNull);
    });

    test('"No reconocido", secuencia vacía o clase no habilitada', () async {
      final m = TestModeGestureRecognitionService()..setTestOutcome(null);
      expect((await m.recognize(frame, candidateClasses: ['gesto_agua']))
          .recognized, isFalse);
      m.setTestOutcome('gesto_agua');
      expect((await m.recognize(seq, candidateClasses: ['gesto_agua']))
          .recognized, isFalse);
      m.setTestOutcome('gesto_hola');
      expect((await m.recognize(frame, candidateClasses: ['gesto_agua']))
          .recognized, isFalse);
    });
  });

  test('ReportBuilder resume por recurso, gesto e intención (E6)', () {
    final now = DateTime(2026, 10, 7, 12);
    InteractionRecord rec(int picto, DateTime at, {int? gesture}) =>
        InteractionRecord(
          interaction: Interaction(
              at: at,
              profileId: 1,
              pictogramId: picto,
              gestureId: gesture,
              intentionId: gesture),
          pictogramName: 'P$picto',
          pictogramMessage: 'M$picto',
          pictogramHasImage: false,
          categoryId: 1,
        );
    final s = const ReportBuilder().build([
      rec(1, now),
      rec(1, now.subtract(const Duration(days: 1)), gesture: 5),
      rec(2, now),
    ], now: now);
    expect(s.totalInteractions, 3);
    expect(s.gestureInteractions, 1);
    expect(s.distinctIntentions, 1);
    expect(s.weekly.last, 2);
    expect(s.frequent.first.pictogramId, 1);
    expect(s.hasEnoughForFrequencies, isTrue);
  });

  testWidgets('PictoTile muestra el pictograma y su estado seleccionado',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(highContrast: false),
      home: Scaffold(
        body: SizedBox(
          width: 140,
          height: 160,
          child: PictoTile(
            pictogram: const Pictogram(
                id: 1,
                name: 'Agua',
                message: 'Quiero agua',
                categoryId: 1,
                emoji: '💧'),
            background: AppColors.blue,
            accent: AppColors.blueAccent,
            selected: true,
            onTap: () => taps++,
          ),
        ),
      ),
    ));
    expect(find.text('Agua'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Agua'));
    expect(taps, 1);
  });

  testWidgets('Diálogo de contraseña: cancelar, error y aceptar sin fallos',
      (tester) async {
    String? result = 'sin-abrir';
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(highContrast: false),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showTextInputDialog(
                context,
                title: 'Salir del panel del niño',
                label: 'Contraseña del tutor',
                confirmLabel: 'Salir',
                obscure: true,
                validate: (v) async =>
                    v == 'correcta' ? null : 'Contraseña incorrecta',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));

    // Cancelar
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);

    // Contraseña incorrecta: el diálogo sigue abierto con el error
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mala');
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Contraseña incorrecta'), findsOneWidget);

    // Contraseña correcta: se cierra y devuelve el valor
    await tester.enterText(find.byType(TextField), 'correcta');
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(result, 'correcta');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
