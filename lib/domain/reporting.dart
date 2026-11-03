/// Resumenes DESCRIPTIVOS del uso de la aplicacion. No realiza evaluaciones ni
/// interpretaciones clinicas.
library;

import 'interaction.dart';

/// Recurso comunicativo y numero de usos.
class FrequentResource {
  final int pictogramId;
  final String name;
  final String message;
  final String? emoji;
  final int count;

  const FrequentResource({
    required this.pictogramId,
    required this.name,
    required this.message,
    this.emoji,
    required this.count,
  });
}

class UsageSummary {
  final int totalInteractions;
  final int gestureInteractions;
  final int pictogramInteractions;
  final int distinctIntentions;

  /// Conteo por dia, ultimos 7 (indice 0 = hace 6 dias).
  final List<int> weekly;
  final List<FrequentResource> frequent;

  const UsageSummary({
    required this.totalInteractions,
    required this.gestureInteractions,
    required this.pictogramInteractions,
    required this.distinctIntentions,
    required this.weekly,
    required this.frequent,
  });

  /// Minimo de registros para mostrar frecuencias.
  static const minRecordsForFrequencies = 3;
  bool get hasEnoughForFrequencies =>
      totalInteractions >= minRecordsForFrequencies;
}

/// Construye el resumen a partir del historial.
class ReportBuilder {
  const ReportBuilder();

  UsageSummary build(List<InteractionRecord> records, {DateTime? now}) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekly = List<int>.filled(7, 0);
    var gestures = 0;
    final intentions = <int>{};
    final counts = <int, int>{};
    final byPicto = <int, InteractionRecord>{};

    for (final r in records) {
      final i = r.interaction;
      final d = DateTime(i.at.year, i.at.month, i.at.day);
      final diff = today.difference(d).inDays;
      if (diff >= 0 && diff < 7) weekly[6 - diff]++;
      if (i.source == InteractionSource.gesture) gestures++;
      if (i.intentionId != null) intentions.add(i.intentionId!);
      counts[i.pictogramId] = (counts[i.pictogramId] ?? 0) + 1;
      byPicto[i.pictogramId] ??= r;
    }

    final frequent = counts.entries
        .map((e) => FrequentResource(
              pictogramId: e.key,
              name: byPicto[e.key]!.pictogramName,
              message: byPicto[e.key]!.pictogramMessage,
              emoji: byPicto[e.key]!.pictogramEmoji,
              count: e.value,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return UsageSummary(
      totalInteractions: records.length,
      gestureInteractions: gestures,
      pictogramInteractions: records.length - gestures,
      distinctIntentions: intentions.length,
      weekly: weekly,
      frequent: frequent.take(8).toList(),
    );
  }
}

/// Puerto: de donde se obtiene el historial y su resumen. Local (SQLite) o
/// remoto (backend).
abstract interface class HistorySource {
  /// Interacciones del periodo [from, to).
  Future<List<InteractionRecord>> records(int profileId,
      {DateTime? from, DateTime? to});

  /// Resumen del periodo [from, to).
  Future<UsageSummary> summary(int profileId, {DateTime? from, DateTime? to});

  /// Detalle de una interaccion; null si ya no esta disponible.
  Future<InteractionRecord?> detail(int profileId, InteractionRecord record);
}

/// Puerto: exporta el historial a un archivo: reporte PDF con graficos o datos
/// CSV para Excel. Devuelve la ruta del archivo.
abstract interface class ReportExporter {
  Future<String> exportCsv(
      String profileName, String periodLabel, List<InteractionRecord> records);

  Future<String> exportPdf(String profileName, String periodLabel,
      List<InteractionRecord> records, UsageSummary summary);
}
