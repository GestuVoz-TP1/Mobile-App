import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../application/reporting_service.dart';
import '../../domain/interaction.dart';
import '../../domain/reporting.dart';
import 'session_controller.dart';

/// Periodos del filtro de historial (mockup 12, HU032).
enum HistoryPeriod { today, week, all, custom }

extension HistoryPeriodX on HistoryPeriod {
  String get label => switch (this) {
        HistoryPeriod.today => 'Hoy',
        HistoryPeriod.week => 'Últimos 7 días',
        HistoryPeriod.all => 'Todo',
        HistoryPeriod.custom => 'Fechas',
      };
}

/// Estado de la pantalla "Historial y reportes" (E6).
class ReportingController extends ChangeNotifier {
  ReportingController(this._service, this._session);
  final ReportingService _service;
  final SessionController _session;

  HistoryPeriod _period = HistoryPeriod.week;
  HistoryPeriod get period => _period;

  DateTimeRange? _range;
  DateTimeRange? get customRange => _range;

  List<InteractionRecord> _records = const [];
  List<InteractionRecord> get records => _records;

  UsageSummary? _summary;
  UsageSummary? get summary => _summary;

  /// Actividad de los ultimos 7 dias (grafico del mockup 12).
  UsageSummary? _week;
  UsageSummary? get week => _week;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  String? lastExportPath;

  (DateTime?, DateTime?) _bounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return switch (_period) {
      HistoryPeriod.today => (today, tomorrow),
      HistoryPeriod.week => (today.subtract(const Duration(days: 6)), tomorrow),
      HistoryPeriod.all => (null, null),
      HistoryPeriod.custom => _range == null
          ? (null, null)
          : (
              DateTime(_range!.start.year, _range!.start.month,
                  _range!.start.day),
              DateTime(_range!.end.year, _range!.end.month, _range!.end.day)
                  .add(const Duration(days: 1)),
            ),
    };
  }

  Future<void> refresh() async {
    final profile = _session.activeProfile;
    if (profile == null) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final (from, to) = _bounds();
      _records = await _service.records(profile.id!, from: from, to: to);
      _summary = _service.summarize(_records);
      _week = await _service.weekSummary(profile.id!);
    } catch (_) {
      _error = 'No se pudo cargar el historial.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setPeriod(HistoryPeriod p, {DateTimeRange? range}) async {
    _period = p;
    if (p == HistoryPeriod.custom) _range = range;
    await refresh();
  }

  Future<InteractionRecord?> detail(int id) => _service.detail(id);

  Future<void> exportCsv() async {
    final profile = _session.activeProfile;
    if (profile == null) return;
    _busy = true;
    notifyListeners();
    try {
      lastExportPath =
          await _service.exportCsv(profile.child.name, _records);
    } catch (_) {
      _error = 'No se pudo exportar el historial.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
