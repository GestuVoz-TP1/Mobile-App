import '../domain/interaction.dart';
import '../domain/reporting.dart';

/// Servicio de aplicacion del historial (E6, HU030-HU033).
class ReportingService {
  ReportingService(this._interactions, this._exporter,
      {ReportBuilder builder = const ReportBuilder()})
      : _builder = builder;

  final InteractionRepository _interactions;
  final ReportExporter _exporter;
  final ReportBuilder _builder;

  /// HU030 / HU032: historial del perfil en el periodo [from, to).
  Future<List<InteractionRecord>> records(int profileId,
          {DateTime? from, DateTime? to}) =>
      _interactions.recordsForProfile(profileId, from: from, to: to);

  /// HU031 y resumen del mockup 12.
  UsageSummary summarize(List<InteractionRecord> records) =>
      _builder.build(records);

  Future<UsageSummary> weekSummary(int profileId) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    return _builder.build(await records(profileId, from: from));
  }

  /// HU033.
  Future<InteractionRecord?> detail(int interactionId) =>
      _interactions.recordById(interactionId);

  Future<String> exportCsv(
          String profileName, List<InteractionRecord> records) =>
      _exporter.exportCsv(profileName, records);
}
