import 'package:flutter/material.dart';
import 'package:flutter_application_1/theme.dart';

class MotivationCard extends StatelessWidget {
  final int streak;
  final String quote;
  const MotivationCard({super.key, required this.streak, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: kPrimaryGreen, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('$streak DAY STREAK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            quote,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18, height: 1.25),
          ),
        ],
      ),
    );
  }
}
