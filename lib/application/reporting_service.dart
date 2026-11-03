import '../domain/interaction.dart';
import '../domain/reporting.dart';

class LocalHistorySource implements HistorySource {
  LocalHistorySource(this._interactions,
      {ReportBuilder builder = const ReportBuilder()})
      : _builder = builder;

  final InteractionRepository _interactions;
  final ReportBuilder _builder;

  @override
  Future<List<InteractionRecord>> records(int profileId,
          {DateTime? from, DateTime? to}) =>
      _interactions.recordsForProfile(profileId, from: from, to: to);

  @override
  Future<UsageSummary> summary(int profileId,
          {DateTime? from, DateTime? to}) async =>
      _builder.build(await records(profileId, from: from, to: to));

  @override
  Future<InteractionRecord?> detail(int profileId, InteractionRecord record) =>
      _interactions.recordById(record.interaction.id!);
}

class ReportingService {
  ReportingService(
    this._interactions,
    this._exporter, {
    ReportBuilder builder = const ReportBuilder(),
    HistorySource? history,
  })  : _builder = builder,
        _history = history ??
            LocalHistorySource(_interactions, builder: builder);

  final InteractionRepository _interactions;
  final ReportExporter _exporter;
  final ReportBuilder _builder;
  final HistorySource _history;

  Future<List<InteractionRecord>> records(int profileId,
          {DateTime? from, DateTime? to}) =>
      _interactions.recordsForProfile(profileId, from: from, to: to);

  UsageSummary summarize(List<InteractionRecord> records) =>
      _builder.build(records);

  Future<List<InteractionRecord>> historyRecords(int profileId,
          {DateTime? from, DateTime? to}) =>
      _history.records(profileId, from: from, to: to);

  Future<UsageSummary> historySummary(int profileId,
          {DateTime? from, DateTime? to}) =>
      _history.summary(profileId, from: from, to: to);

  Future<UsageSummary> weekSummary(int profileId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _history.summary(profileId,
        from: today.subtract(const Duration(days: 6)),
        to: today.add(const Duration(days: 1)));
  }

  Future<InteractionRecord?> detail(int profileId, InteractionRecord record) =>
      _history.detail(profileId, record);

  Future<String> exportCsv(String profileName, String periodLabel,
          List<InteractionRecord> records) =>
      _exporter.exportCsv(profileName, periodLabel, records);

  Future<String> exportPdf(String profileName, String periodLabel,
          List<InteractionRecord> records, UsageSummary summary) =>
      _exporter.exportPdf(profileName, periodLabel, records, summary);
}
