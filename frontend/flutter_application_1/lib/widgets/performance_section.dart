import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class PerformanceSection extends StatelessWidget {
  final double performance;
  final double average;
  const PerformanceSection({super.key, required this.performance, required this.average});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Text('Performance Score')),
                  const SizedBox(height: 8),
                  CircularPercentIndicator(
                    radius: 60,
                    lineWidth: 8,
                    percent: performance,
                    center: Text('${(performance * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    progressColor: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Average Score'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.show_chart, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('${(average * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }
}
