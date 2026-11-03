import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestuvoz/domain/interaction.dart';
import 'package:gestuvoz/domain/reporting.dart';
import 'package:gestuvoz/infrastructure/persistence/report_exporter.dart';

InteractionRecord _record(DateTime at, String name, String message,
        {String? detail, int picto = 1, int? gesture}) =>
    InteractionRecord(
      interaction: Interaction(
        at: at,
        detail: detail,
        profileId: 1,
        pictogramId: picto,
        gestureId: gesture,
        intentionId: gesture,
      ),
      pictogramName: name,
      pictogramMessage: message,
      pictogramHasImage: false,
      categoryId: 1,
      gestureName: gesture == null ? null : 'Sí',
      intentionName: gesture == null ? null : 'Decir que sí',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final records = [
    _record(DateTime(2026, 11, 2, 9, 15), 'Sí', 'Sí', detail: 'Sí', gesture: 5),
    _record(DateTime(2026, 11, 3, 16, 40), 'Sí', 'Sí',
        detail: 'Estoy bien; gracias', gesture: 5),
    _record(DateTime(2026, 11, 3, 17, 5), 'Hambre', 'Tengo hambre',
        detail: 'Tengo hambre', picto: 2),
    _record(DateTime(2026, 11, 3, 17, 6), 'Comer', 'Quiero comer',
        detail: '=SUMA(A1)', picto: 3),
  ];

  test('El CSV abre bien en Excel: tildes, columnas y sin fórmulas', () {
    final bytes = buildReportCsv('Valentina López', 'Todo', records);
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]); // UTF-8 para Excel
    final lines = utf8.decode(bytes.sublist(3)).split('\n');
    expect(lines[0].trim(), 'Historial de uso;Valentina López');
    expect(lines[1].trim(), 'Período;Todo');
    expect(lines[4].trim(), 'Fecha;Hora;Recurso;Pictograma;Mensaje;Gesto;Intención');
    expect(lines[5].trim(), '02/11/2026;09:15;Gesto;Sí;Sí;Sí;Decir que sí');
    // El punto y coma dentro de una frase no parte la columna.
    expect(lines[6], contains('"Estoy bien; gracias"'));
    // Un texto que empieza con = no se ejecuta como fórmula.
    expect(lines[8], contains("'=SUMA(A1)"));
  });

  test('El PDF se genera con varias páginas de detalle', () async {
    final summary = const ReportBuilder().build(records);
    Future<Uint8List> pdf(List<InteractionRecord> r) async => buildReportPdf(
          profileName: 'Valentina López',
          periodLabel: 'Todo',
          records: r,
          summary: const ReportBuilder().build(r),
          regular: ByteData.sublistView(
              File('assets/fonts/Baloo2-Regular.ttf').readAsBytesSync()),
          bold: ByteData.sublistView(
              File('assets/fonts/Baloo2-Bold.ttf').readAsBytesSync()),
          now: DateTime(2026, 11, 3),
        );
    expect(summary.totalInteractions, 4);
    final bytes = await pdf(records);
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');

    final muchos = [
      for (var i = 0; i < 300; i++)
        _record(DateTime(2026, 1, 1).add(Duration(hours: i * 7)), 'Pictograma $i',
            'Mensaje $i', detail: 'Mensaje $i', picto: i % 12, gesture: i % 3 == 0 ? 5 : null)
    ];
    final largo = await pdf(muchos);

    final dir = Platform.environment['GV_REPORTES'];
    if (dir != null) {
      File('$dir/corto.pdf').writeAsBytesSync(bytes);
      File('$dir/largo.pdf').writeAsBytesSync(largo);
      File('$dir/datos.csv').writeAsBytesSync(
          buildReportCsv('Valentina López', 'Todo', records));
    }
    expect(largo.length, greaterThan(bytes.length));
  });
}
