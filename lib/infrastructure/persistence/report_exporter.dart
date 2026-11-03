import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/interaction.dart';
import '../../domain/reporting.dart';

/// Genera los archivos del historial: reporte PDF con graficos y datos CSV
/// para Excel. Se guardan en la carpeta temporal, porque solo existen para
/// compartirlos: el tutor decide a donde enviarlos.
class FileReportExporter implements ReportExporter {
  @override
  Future<String> exportCsv(String profileName, String periodLabel,
      List<InteractionRecord> records) async {
    final file = await _file(profileName, 'csv');
    await file.writeAsBytes(buildReportCsv(profileName, periodLabel, records));
    return file.path;
  }

  @override
  Future<String> exportPdf(String profileName, String periodLabel,
      List<InteractionRecord> records, UsageSummary summary) async {
    final bytes = await buildReportPdf(
      profileName: profileName,
      periodLabel: periodLabel,
      records: records,
      summary: summary,
      regular: await rootBundle.load('assets/fonts/Baloo2-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Baloo2-Bold.ttf'),
    );
    final file = await _file(profileName, 'pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<File> _file(String profileName, String extension) async {
    final dir = await getTemporaryDirectory();
    final safe = profileName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return File('${dir.path}/reporte_${safe}_${_isoDate(DateTime.now())}.$extension');
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
String _isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// CSV para Excel: UTF-8 con marca de orden, para que muestre bien las tildes,
/// y punto y coma, el separador de listas de Excel en español.
Uint8List buildReportCsv(String profileName, String periodLabel,
    List<InteractionRecord> records) {
  String cell(String v) {
    // Un texto escrito por el tutor no debe ejecutarse como formula en Excel.
    final safe = v.startsWith(RegExp(r'[=+\-@]')) ? "'$v" : v;
    return safe.contains(RegExp(r'[;"\n\r]'))
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  final b = StringBuffer()
    ..writeln('Historial de uso;${cell(profileName)}')
    ..writeln('Período;${cell(periodLabel)}')
    ..writeln('Interacciones;${records.length}')
    ..writeln()
    ..writeln('Fecha;Hora;Recurso;Pictograma;Mensaje;Gesto;Intención');
  final sorted = [...records]
    ..sort((a, b) => a.interaction.at.compareTo(b.interaction.at));
  for (final r in sorted) {
    final d = r.interaction.at;
    b.writeln([
      _date(d),
      _time(d),
      r.interaction.source.label,
      cell(r.pictogramName),
      cell(r.message),
      cell(r.gestureName ?? ''),
      cell(r.intentionName ?? ''),
    ].join(';'));
  }
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())]);
}

const _primary = PdfColor.fromInt(0xFF276B62);
const _soft = PdfColor.fromInt(0xFFDDF0EB);
const _ink = PdfColor.fromInt(0xFF15302B);
const _inkSoft = PdfColor.fromInt(0xFF44544E);
const _line = PdfColor.fromInt(0xFFDDE5E2);
const _coral = PdfColor.fromInt(0xFFD9584A);

/// Reporte descriptivo de uso: resumen, graficos y detalle.
Future<Uint8List> buildReportPdf({
  required String profileName,
  required String periodLabel,
  required List<InteractionRecord> records,
  required UsageSummary summary,
  required ByteData regular,
  required ByteData bold,
  DateTime? now,
}) async {
  final generated = now ?? DateTime.now();
  final doc = pw.Document(
    title: 'Reporte de uso de GestuVoz',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ),
  );
  final sorted = [...records]
    ..sort((a, b) => b.interaction.at.compareTo(a.interaction.at));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    footer: (context) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('GestuVoz · Generado el ${_date(generated)}',
            style: const pw.TextStyle(fontSize: 9, color: _inkSoft)),
        pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _inkSoft)),
      ],
    ),
    build: (context) => [
      pw.Text('Reporte de uso',
          style: pw.TextStyle(
              fontSize: 26, fontWeight: pw.FontWeight.bold, color: _ink)),
      pw.Text(profileName,
          style: pw.TextStyle(
              fontSize: 15, fontWeight: pw.FontWeight.bold, color: _primary)),
      pw.Text('Período: $periodLabel',
          style: const pw.TextStyle(fontSize: 11, color: _inkSoft)),
      pw.SizedBox(height: 14),
      pw.Row(children: [
        _stat('${summary.totalInteractions}', 'Interacciones', dark: true),
        pw.SizedBox(width: 8),
        _stat('${summary.gestureInteractions}', 'Por gestos'),
        pw.SizedBox(width: 8),
        _stat('${summary.pictogramInteractions}', 'Por pictogramas'),
        pw.SizedBox(width: 8),
        _stat('${summary.distinctIntentions}', 'Intenciones distintas'),
      ]),
      _title('Actividad'),
      _activityChart(records),
      _title('Recursos utilizados'),
      _sourcesBar(summary),
      _title('Pictogramas más usados'),
      if (summary.hasEnoughForFrequencies)
        ..._frequentBars(summary)
      else
        pw.Text('Todavía no hay datos suficientes para mostrar frecuencias.',
            style: const pw.TextStyle(fontSize: 11, color: _inkSoft)),
      _title('Detalle de interacciones'),
      pw.TableHelper.fromTextArray(
        headers: const ['Fecha', 'Hora', 'Recurso', 'Pictograma', 'Mensaje', 'Gesto'],
        data: [
          for (final r in sorted)
            [
              _date(r.interaction.at),
              _time(r.interaction.at),
              r.interaction.source.label,
              r.pictogramName,
              r.message,
              r.gestureName ?? '—',
            ],
        ],
        headerStyle: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 9.5, color: _ink),
        cellAlignment: pw.Alignment.centerLeft,
        border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _line, width: 0.5),
            bottom: pw.BorderSide(color: _line, width: 0.5)),
        columnWidths: const {
          0: pw.FixedColumnWidth(62),
          1: pw.FixedColumnWidth(38),
          2: pw.FixedColumnWidth(56),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(3),
          5: pw.FlexColumnWidth(1.4),
        },
      ),
      pw.SizedBox(height: 12),
      pw.Text(
          'Resumen descriptivo del uso de la aplicación. No constituye una '
          'evaluación ni una interpretación clínica.',
          style: const pw.TextStyle(fontSize: 9, color: _inkSoft)),
    ],
  ));
  return doc.save();
}

pw.Widget _title(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink)),
    );

pw.Widget _stat(String value, String label, {bool dark = false}) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: dark ? _primary : _soft,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: dark ? PdfColors.white : _ink)),
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9.5, color: dark ? PdfColors.white : _inkSoft)),
          ],
        ),
      ),
    );

/// Interacciones por dia; por mes si el periodo supera los 31 dias.
pw.Widget _activityChart(List<InteractionRecord> records) {
  if (records.isEmpty) return pw.SizedBox();
  final days = [
    for (final r in records)
      DateTime(r.interaction.at.year, r.interaction.at.month, r.interaction.at.day)
  ]..sort();
  final first = days.first, last = days.last;
  final byMonth = last.difference(first).inDays > 31;
  final counts = <DateTime, int>{};
  if (byMonth) {
    for (var m = DateTime(first.year, first.month);
        !m.isAfter(last);
        m = DateTime(m.year, m.month + 1)) {
      counts[m] = 0;
    }
    for (final d in days) {
      final k = DateTime(d.year, d.month);
      counts[k] = counts[k]! + 1;
    }
  } else {
    for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      counts[d] = 0;
    }
    for (final d in days) {
      counts[d] = counts[d]! + 1;
    }
  }
  final top = counts.values.reduce(math.max);
  const height = 90.0;
  final many = counts.length > 14;
  return pw.Column(children: [
    pw.SizedBox(
      height: height + 16,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final v in counts.values)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    if (v > 0 && !many)
                      pw.Text('$v',
                          style: const pw.TextStyle(fontSize: 8, color: _ink)),
                    pw.Container(
                      height: math.max(v / top * height, v > 0 ? 2 : 0.5),
                      color: v > 0 ? _primary : _line,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    pw.Row(children: [
      for (final (i, d) in counts.keys.indexed)
        pw.Expanded(
          child: pw.Text(
            // Con muchos dias, una etiqueta de cada varias para que se lean.
            many && i % (counts.length ~/ 7 + 1) != 0
                ? ''
                : byMonth
                    ? '${_two(d.month)}/${d.year % 100}'
                    : '${_two(d.day)}/${_two(d.month)}',
            textAlign: pw.TextAlign.center,
            softWrap: false,
            overflow: pw.TextOverflow.visible,
            style: const pw.TextStyle(fontSize: 7.5, color: _inkSoft),
          ),
        ),
    ]),
  ]);
}

pw.Widget _sourcesBar(UsageSummary s) {
  final total = s.totalInteractions;
  if (total == 0) return pw.SizedBox();
  pw.Widget legend(PdfColor color, String text) => pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(width: 9, height: 9, color: color),
          pw.SizedBox(width: 4),
          pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: _ink)),
          pw.SizedBox(width: 14),
        ],
      );
  String pct(int n) => '${(n * 100 / total).round()} %';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.ClipRRect(
        horizontalRadius: 4,
        verticalRadius: 4,
        child: pw.Row(children: [
          if (s.gestureInteractions > 0)
            pw.Expanded(
                flex: s.gestureInteractions,
                child: pw.Container(height: 16, color: _coral)),
          if (s.pictogramInteractions > 0)
            pw.Expanded(
                flex: s.pictogramInteractions,
                child: pw.Container(height: 16, color: _primary)),
        ]),
      ),
      pw.SizedBox(height: 5),
      pw.Row(children: [
        legend(_coral, 'Gestos: ${s.gestureInteractions} (${pct(s.gestureInteractions)})'),
        legend(_primary,
            'Pictogramas: ${s.pictogramInteractions} (${pct(s.pictogramInteractions)})'),
      ]),
    ],
  );
}

List<pw.Widget> _frequentBars(UsageSummary s) {
  final top = s.frequent.isEmpty ? 1 : s.frequent.first.count;
  return [
    for (final f in s.frequent)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(f.name,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 10, color: _ink)),
          ),
          pw.Expanded(
            child: pw.Row(children: [
              pw.Expanded(
                  flex: f.count,
                  child: pw.Container(height: 10, color: _primary)),
              if (top > f.count)
                pw.Expanded(flex: top - f.count, child: pw.SizedBox()),
            ]),
          ),
          pw.SizedBox(
            width: 28,
            child: pw.Text('${f.count}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
          ),
        ]),
      ),
  ];
}
