library;

import 'interaction.dart';

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

  static const minRecordsForFrequencies = 3;
  bool get hasEnoughForFrequencies =>
      totalInteractions >= minRecordsForFrequencies;
}

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

abstract interface class HistorySource {
  Future<List<InteractionRecord>> records(int profileId,
      {DateTime? from, DateTime? to});

  Future<UsageSummary> summary(int profileId, {DateTime? from, DateTime? to});

  Future<InteractionRecord?> detail(int profileId, InteractionRecord record);
}

abstract interface class ReportExporter {
  Future<String> exportCsv(
      String profileName, String periodLabel, List<InteractionRecord> records);

  Future<String> exportPdf(String profileName, String periodLabel,
      List<InteractionRecord> records, UsageSummary summary);
}
