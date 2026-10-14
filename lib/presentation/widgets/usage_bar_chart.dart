import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Barras de interacciones por dia (ultimos 7), como en el mockup 12.
class WeeklyUsageChart extends StatelessWidget {
  final List<int> counts;
  const WeeklyUsageChart({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final peak = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
    final maxY = (peak + 2).toDouble();
    final now = DateTime.now();
    const names = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
    return Semantics(
      label: 'Interacciones de los últimos 7 días: ${counts.join(', ')}',
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY < 5 ? 5 : maxY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${rod.toY.toInt()}',
                const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i > 6) return const SizedBox.shrink();
                  final d = now.subtract(Duration(days: 6 - i));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(names[d.weekday % 7],
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < counts.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: counts[i].toDouble(),
                  width: 22,
                  borderRadius: BorderRadius.circular(8),
                  color: i == counts.length - 1
                      ? AppColors.primary
                      : AppColors.primarySoft,
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
