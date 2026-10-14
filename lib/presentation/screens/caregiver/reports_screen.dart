import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/interaction.dart';
import '../../../domain/reporting.dart';
import '../../category_style.dart';
import '../../controllers/reporting_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/picto_visual.dart';
import '../../widgets/usage_bar_chart.dart';

/// Historial y reportes (mockup 12, E6). Consulta descriptiva del uso; no
/// realiza evaluaciones ni interpretaciones clinicas.
class HistoryScreen extends StatefulWidget {
  /// true = se muestra dentro de la pestana "Reportes" del panel del tutor.
  final bool embedded;
  const HistoryScreen({super.key, this.embedded = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<ReportingController>().refresh());
  }

  Future<void> _choosePeriod(HistoryPeriod p) async {
    final rc = context.read<ReportingController>();
    if (p != HistoryPeriod.custom) return rc.setPeriod(p);
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: rc.customRange,
      helpText: 'Selecciona el período',
    );
    if (range != null) await rc.setPeriod(p, range: range);
  }

  Future<void> _export() async {
    final rc = context.read<ReportingController>();
    await rc.exportCsv();
    if (!mounted || rc.lastExportPath == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Historial exportado'),
        content: Text('Archivo CSV guardado en:\n${rc.lastExportPath}'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<ReportingController>();
    final session = context.watch<SessionController>();
    final name = session.activeProfile?.child.name ?? '';
    final summary = rc.summary;
    final body = rc.error != null && summary == null
        ? RetryPanel(message: rc.error!, onRetry: rc.refresh)
        : RefreshIndicator(
            onRefresh: rc.refresh,
            child: ListView(
              padding: const EdgeInsets.all(Insets.md),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Historial y reportes',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)),
                          Text('Interacciones de $name',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Exportar CSV',
                      onPressed:
                          rc.busy || rc.records.isEmpty ? null : _export,
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final p in HistoryPeriod.values)
                      ChoiceChip(
                        avatar: p == HistoryPeriod.custom
                            ? const Icon(Icons.date_range_rounded, size: 18)
                            : null,
                        label: Text(p == HistoryPeriod.custom &&
                                rc.customRange != null &&
                                rc.period == p
                            ? '${formatDate(rc.customRange!.start)} – ${formatDate(rc.customRange!.end)}'
                            : p.label),
                        selected: rc.period == p,
                        onSelected: (_) => _choosePeriod(p),
                      ),
                  ],
                ),
                if (!session.consentAllowsProcessing) ...[
                  const SizedBox(height: Insets.md),
                  const StatusNote(
                    'El consentimiento no está vigente: no se registran nuevas '
                    'interacciones para este perfil.',
                    kind: NoteKind.warning,
                  ),
                ],
                const SizedBox(height: Insets.md),
                if (summary != null) _StatsRow(summary: summary),
                const SizedBox(height: Insets.md),
                if (rc.week != null) _WeekCard(week: rc.week!),
                if (summary != null) _FrequentCard(summary: summary),
                SectionTitle('Interacciones',
                    trailing: Text('${rc.records.length} registros',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant))),
                if (rc.busy && rc.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(Insets.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rc.records.isEmpty)
                  rc.period == HistoryPeriod.all
                      // HU030, criterio 2
                      ? const EmptyState(
                          emoji: '🗒️',
                          title: 'Todavía no hay registros',
                          message: 'Las interacciones aparecerán aquí cuando '
                              'el niño use pictogramas o gestos.')
                      // HU032, criterio 2
                      : EmptyState(
                          emoji: '📅',
                          title: 'No hay resultados en este período',
                          action: OutlinedButton(
                            onPressed: () =>
                                _choosePeriod(HistoryPeriod.all),
                            child: const Text('Ver todo el historial'),
                          ),
                        )
                else
                  for (final r in rc.records) _RecordTile(record: r),
              ],
            ),
          );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(), body: SafeArea(child: body));
  }
}

class _StatsRow extends StatelessWidget {
  final UsageSummary summary;
  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: _StatBox('${summary.totalInteractions}', 'interacciones',
                  dark: true)),
          const SizedBox(width: Insets.sm),
          Expanded(
              child:
                  _StatBox('${summary.gestureInteractions}', 'por gestos')),
          const SizedBox(width: Insets.sm),
          Expanded(
              child: _StatBox('${summary.distinctIntentions}', 'intenciones')),
        ],
      );
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final bool dark;
  const _StatBox(this.value, this.label, {this.dark = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: dark ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : AppColors.ink)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.inkSoft)),
          ],
        ),
      );
}

class _WeekCard extends StatelessWidget {
  final UsageSummary week;
  const _WeekCard({required this.week});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Actividad de los últimos 7 días',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: Insets.md),
              SizedBox(
                  height: 150, child: WeeklyUsageChart(counts: week.weekly)),
            ],
          ),
        ),
      );
}

/// HU031: mensajes y recursos mas usados en el periodo.
class _FrequentCard extends StatelessWidget {
  final UsageSummary summary;
  const _FrequentCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final max = summary.frequent.isEmpty ? 1 : summary.frequent.first.count;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mensajes más usados',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: Insets.sm),
              if (!summary.hasEnoughForFrequencies)
                const Text('Todavía no hay datos suficientes para mostrar '
                    'frecuencias.')
              else
                for (final f in summary.frequent)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Center(
                              child: Text(f.emoji ?? '🖼️',
                                  style: const TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          flex: 3,
                          child: Text(f.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: f.count / max,
                              minHeight: 10,
                              color: AppColors.primary,
                              backgroundColor: AppColors.primarySoft,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text('${f.count}',
                              textAlign: TextAlign.end,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final InteractionRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final i = record.interaction;
    final style = CategoryStyle.of(record.categoryId);
    final isGesture = i.source == InteractionSource.gesture;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => showInteractionDetail(context, i.id!),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                      record.pictogramHasImage
                          ? '🖼️'
                          : (record.pictogramEmoji ?? '🖼️'),
                      style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.pictogramMessage,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          Text('${formatDate(i.at)} · ${formatTime(i.at)} · '),
                          Icon(
                              isGesture
                                  ? Icons.back_hand_outlined
                                  : Icons.grid_view_rounded,
                              size: 14,
                              color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(i.source.label,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// HU033: detalle de una interaccion (fecha, hora y recurso utilizado).
Future<void> showInteractionDetail(BuildContext context, int id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => FutureBuilder<InteractionRecord?>(
      future: context.read<ReportingController>().detail(id),
      builder: (ctx, snap) {
        Widget child;
        if (snap.connectionState != ConnectionState.done) {
          child = const Padding(
            padding: EdgeInsets.all(Insets.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snap.data == null) {
          // HU033, criterio 2
          child = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StatusNote('Este registro ya no está disponible.',
                  kind: NoteKind.error),
              const SizedBox(height: Insets.md),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Volver al historial'),
              ),
            ],
          );
        } else {
          final r = snap.data!;
          final i = r.interaction;
          child = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: CategoryStyle.of(r.categoryId).background,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: PictoGlyph(
                        emoji: r.pictogramHasImage ? '🖼️' : r.pictogramEmoji,
                        size: 34),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text('“${r.pictogramMessage}”',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              _DetailRow('Fecha', formatDate(i.at)),
              _DetailRow('Hora', formatTime(i.at)),
              _DetailRow('Recurso', i.source.label),
              _DetailRow('Pictograma', r.pictogramName),
              if (r.gestureName != null) _DetailRow('Gesto', r.gestureName!),
              if (r.intentionName != null)
                _DetailRow('Intención', r.intentionName!),
              if (i.detail != null) _DetailRow('Detalle', i.detail!),
              const SizedBox(height: Insets.md),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Volver al historial'),
              ),
            ],
          );
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: child,
          ),
        );
      },
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
