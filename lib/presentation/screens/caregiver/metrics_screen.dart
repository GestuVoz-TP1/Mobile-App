import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../infrastructure/metrics/recognition_metrics.dart';
import '../../responsive.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  final _sessionField = TextEditingController();
  String _current = RecognitionMetricsStore.defaultSession;
  List<String> _sessions = const [];
  String? _filter;
  MetricsSummary? _summary;
  bool _loading = true;

  RecognitionMetricsStore get _store => context.read<RecognitionMetricsStore>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _sessionField.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final current = await _store.currentSession();
    final sessions = await _store.sessions();
    final filter = _filter != null && sessions.contains(_filter) ? _filter : null;
    final events = await _store.events(session: filter);
    if (!mounted) return;
    setState(() {
      _current = current;
      _sessionField.text = current == RecognitionMetricsStore.defaultSession
          ? ''
          : current;
      _sessions = sessions;
      _filter = filter;
      _summary = MetricsSummary.of(events);
      _loading = false;
    });
  }

  Future<void> _saveSession() async {
    await _store.setCurrentSession(_sessionField.text);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión de prueba guardada.')));
    await _load();
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await _store.exportCsv(session: _filter);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'text/csv')],
        title: 'Métricas de reconocimiento de GestuVoz',
      ));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo exportar las métricas.')));
    }
  }

  Future<void> _clear() async {
    final scope = _filter == null ? 'todas las sesiones' : 'la sesión "$_filter"';
    final ok = await confirmDialog(
      context,
      title: 'Borrar métricas',
      message: 'Se eliminarán los registros de $scope. Esta acción no se '
          'puede deshacer. El historial del niño no se modifica.',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (!ok) return;
    await _store.clear(session: _filter);
    await _load();
  }

  String _pct(MetricsSummary s, int v) =>
      '${(s.ratio(v) * 100).toStringAsFixed(1)} %';

  String _ms(num? v) => v == null ? '–' : '${v.round()} ms';

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Métricas de reconocimiento')),
      body: _loading || s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: contentPadding(context),
                children: [
                  const StatusNote(
                    'Estos registros se guardan solo en este teléfono y sirven '
                    'para las pruebas de validación. No se sincronizan ni '
                    'forman parte del historial del niño.',
                  ),
                  const SectionTitle('Sesión de prueba'),
                  Text('Sesión actual: $_current',
                      style: const TextStyle(color: AppColors.inkSoft)),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sessionField,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la sesión',
                            hintText: 'Ej.: Participante 03, día 2',
                          ),
                          onSubmitted: (_) => _saveSession(),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      FilledButton(
                          onPressed: _saveSession, child: const Text('Usar')),
                    ],
                  ),
                  const SectionTitle('Resumen'),
                  DropdownButtonFormField<String?>(
                    initialValue: _filter,
                    decoration: const InputDecoration(labelText: 'Mostrar'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Todas las sesiones')),
                      for (final name in _sessions)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) {
                      _filter = v;
                      _load();
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  _Line('Intentos con la cámara', '${s.attempts}'),
                  _Line('Gestos detectados',
                      '${s.detected} (${_pct(s, s.detected)})'),
                  _Line('Gestos no reconocidos',
                      '${s.notRecognized} (${_pct(s, s.notRecognized)})'),
                  _Line('Confirmados con «Sí, decirlo»',
                      '${s.confirmedByTutor}'),
                  _Line('Rechazados con «No es esto»',
                      '${s.rejectedByTutor}'),
                  _Line('Dichos sin tocar ningún botón',
                      '${s.spokenAutomatically}'),
                  _Line('Latencia media por fotograma', _ms(s.meanFrameMs)),
                  _Line('Latencia máxima por fotograma', _ms(s.maxFrameMs)),
                  _Line('Tiempo medio hasta detectar el gesto',
                      _ms(s.meanResponseMs)),
                  if (s.byGesture.isNotEmpty) ...[
                    const SectionTitle('Por gesto'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Gesto')),
                          DataColumn(label: Text('Detectado'), numeric: true),
                          DataColumn(label: Text('Sí'), numeric: true),
                          DataColumn(label: Text('No'), numeric: true),
                          DataColumn(
                              label: Text('Confianza media'), numeric: true),
                        ],
                        rows: [
                          for (final g in s.byGesture)
                            DataRow(cells: [
                              DataCell(Text(g.gesture)),
                              DataCell(Text('${g.detected}')),
                              DataCell(Text('${g.confirmed}')),
                              DataCell(Text('${g.rejected}')),
                              DataCell(Text(
                                  '${(g.meanConfidence * 100).toStringAsFixed(1)} %')),
                            ]),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Insets.lg),
                  FilledButton.icon(
                    onPressed: s.attempts == 0 &&
                            s.confirmedByTutor + s.rejectedByTutor == 0
                        ? null
                        : _export,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Exportar CSV'),
                  ),
                  const SizedBox(height: Insets.sm),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Borrar métricas'),
                  ),
                  const SizedBox(height: Insets.lg),
                ],
              ),
            ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
