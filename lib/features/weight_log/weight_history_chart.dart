// [HEALTH APP] — Weight History Chart (Feature 7)
// Uses fl_chart to show raw daily dots (grey) + 7-day rolling average (green).
// Primary visual is the trend line — never the raw zigzag.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/weight_log_model.dart';

class WeightHistoryChart extends StatelessWidget {
  final List<WeightLog> entries;
  final String unit; // 'kg' | 'lbs'

  const WeightHistoryChart({
    super.key,
    required this.entries,
    this.unit = 'kg',
  });

  static const double _lbsMultiplier = 2.20462;

  double _toDisplay(double kg) =>
      unit == 'lbs' ? kg * _lbsMultiplier : kg;

  /// Deduplicate entries: one per day (latest wins)
  List<WeightLog> _deduplicated() {
    final Map<String, WeightLog> byDay = {};
    for (final e in entries) {
      final day = _dateStr(e.loggedAt);
      byDay[day] = e;
    }
    final sorted = byDay.values.toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return sorted;
  }

  /// 7-day rolling average for each entry position
  List<double> _rollingAvg(List<WeightLog> sorted) {
    return List.generate(sorted.length, (i) {
      final start = (i - 6).clamp(0, sorted.length - 1);
      final window = sorted.sublist(start, i + 1);
      final sum = window.fold(0.0, (a, e) => a + e.weightKg);
      return sum / window.length;
    });
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _shortDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _deduplicated();

    if (sorted.length < 3) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📈', style: TextStyle(fontSize: 28)),
              SizedBox(height: 8),
              Text(
                'Keep logging — your trend line\nwill appear after a few more entries',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final rollingAvg = _rollingAvg(sorted);
    final allWeights = sorted.map((e) => _toDisplay(e.weightKg)).toList();
    final allAvg = rollingAvg.map(_toDisplay).toList();

    final minY = ([...allWeights, ...allAvg].reduce((a, b) => a < b ? a : b) - 1)
        .floorToDouble();
    final maxY = ([...allWeights, ...allAvg].reduce((a, b) => a > b ? a : b) + 1)
        .ceilToDouble();

    // Raw dots — grey secondary
    final rawSpots = List.generate(
      sorted.length,
      (i) => FlSpot(i.toDouble(), _toDisplay(sorted[i].weightKg)),
    );

    // Rolling average — green primary
    final avgSpots = List.generate(
      sorted.length,
      (i) => FlSpot(i.toDouble(), allAvg[i]),
    );

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFF2A2A2A),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, _) => Text(
                  val.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Color(0xFF666666), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (sorted.length / 4).ceilToDouble().clamp(1, 30),
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= sorted.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _shortDate(sorted[idx].loggedAt),
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 9),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            // Grey raw dots — secondary, no connecting line
            LineChartBarData(
              spots: rawSpots,
              isCurved: false,
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 2.5,
                  color: const Color(0xFF555555),
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                ),
              ),
            ),
            // Green rolling average — PRIMARY
            LineChartBarData(
              spots: avgSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFF4CAF50),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF4CAF50).withOpacity(0.06),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
