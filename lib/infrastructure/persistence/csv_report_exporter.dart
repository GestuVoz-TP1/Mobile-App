import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/interaction.dart';
import '../../domain/reporting.dart';

/// Exporta el historial de interacciones a un CSV (abrible en Excel).
class CsvReportExporter implements ReportExporter {
  @override
  Future<String> exportCsv(
      String profileName, List<InteractionRecord> records) async {
    String cell(String v) => v.contains(',') || v.contains('"')
        ? '"${v.replaceAll('"', '""')}"'
        : v;
    final b = StringBuffer()
      ..writeln('Historial de uso,${cell(profileName)}')
      ..writeln('Interacciones,${records.length}')
      ..writeln('')
      ..writeln('fecha,hora,recurso,pictograma,mensaje,gesto,intencion');
    final sorted = [...records]
      ..sort((a, b) => a.interaction.at.compareTo(b.interaction.at));
    String two(int n) => n.toString().padLeft(2, '0');
    for (final r in sorted) {
      final d = r.interaction.at;
      b.writeln([
        '${d.year}-${two(d.month)}-${two(d.day)}',
        '${two(d.hour)}:${two(d.minute)}',
        r.interaction.source.label,
        cell(r.pictogramName),
        cell(r.pictogramMessage),
        cell(r.gestureName ?? ''),
        cell(r.intentionName ?? ''),
      ].join(','));
    }
    final dir = await getApplicationDocumentsDirectory();
    final safe = profileName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    final stamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/historial_${safe}_$stamp.csv');
    await file.writeAsString(b.toString());
    return file.path;
  }
}
