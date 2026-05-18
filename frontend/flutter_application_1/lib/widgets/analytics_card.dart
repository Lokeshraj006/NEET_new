import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsCard extends StatelessWidget {
  final List<double> values;
  final double mainValue;
  const AnalyticsCard({super.key, required this.values, required this.mainValue});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Average Accuracy', style: TextStyle(fontWeight: FontWeight.w700)),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${mainValue.toStringAsFixed(1)}% ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text('+5.4% vs last week', style: TextStyle(color: Colors.green))])
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(BarChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) { int i = v.toInt(); if (i < 0 || i >= days.length) return const SizedBox.shrink(); return Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(days[i])); })), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              barGroups: List.generate(values.length, (i) {
                final isTallest = i == 3;
                return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], width: 18, color: isTallest ? Colors.green : Colors.green.shade200)]);
              }),
            )),
          )
        ]),
      ),
    );
  }
}
