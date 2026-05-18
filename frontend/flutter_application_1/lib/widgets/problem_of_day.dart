import 'package:flutter/material.dart';

class ProblemOfDay extends StatefulWidget {
  final Map problem;
  const ProblemOfDay({super.key, required this.problem});

  @override
  State<ProblemOfDay> createState() => _ProblemOfDayState();
}

class _ProblemOfDayState extends State<ProblemOfDay> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(widget.problem['subject'], style: const TextStyle(color: Colors.green))),
                const SizedBox(width: 8),
                const Text('Problem of the Day', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.problem['question'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Column(
              children: List.generate(widget.problem['options'].length, (i) {
                final opt = widget.problem['options'][i];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => setState(() => selected = i),
                    child: Row(
                      children: [
                        Icon(selected == i ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected == i ? Colors.green : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(child: Text(opt)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: () {}, child: const Text('View Solution')))
          ],
        ),
      ),
    );
  }
}
