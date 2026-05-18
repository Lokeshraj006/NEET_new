import 'package:flutter/material.dart';
import 'package:flutter_application_1/theme.dart';

class CountdownCard extends StatelessWidget {
  final int daysLeft;
  final double progress;
  const CountdownCard({super.key, required this.daysLeft, required this.progress});

  @override
  Widget build(BuildContext context) {
    final isExamDay = daysLeft == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isExamDay ? Colors.orange : kPrimaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isExamDay ? Icons.emoji_events : Icons.calendar_today,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEET Exam Countdown', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  isExamDay
                      ? const Text(
                          '🎯 All the best for your exam!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                        )
                      : Text(
                          '$daysLeft ${daysLeft == 1 ? 'Day' : 'Days'} Left',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    'NEET Exam: July 14, 2026',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      color: isExamDay ? Colors.orange : kPrimaryGreen,
                      backgroundColor: Colors.grey.shade200,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
