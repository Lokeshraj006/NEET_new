import 'package:flutter/material.dart';

class HomeModel extends ChangeNotifier {
  int selectedIndex = 0;

  void setIndex(int i) {
    selectedIndex = i;
    notifyListeners();
  }

  // Dummy data
  final int streakDays = 14;
  final String quote = 'Success is the sum of small efforts,\nrepeated day in and day out.';
  // NEET exam date: July 14, 2026
  static final DateTime _examDate = DateTime(2026, 7, 14);

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = _examDate.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get progress {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(2025, 7, 14); // one year before exam
    final total = _examDate.difference(start).inDays;
    final elapsed = today.difference(start).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }
  final double performanceScore = 0.88; // 88%
  final double averageScore = 0.842; // 84.2%

  final subjects = [
    {'title': 'Physics'},
    {'title': 'Chemistry'},
    {'title': 'Biology'},
  ];

  final problemOfDay = {
    'subject': 'Physics',
    'question': 'A ray of light passes from air into glass. What happens to its speed?',
    'options': [
      'Increases',
      'Decreases',
      'Remains same',
      'Becomes zero'
    ],
    'answerIndex': 1,
  };

  final accuracyValues = [60.0, 70.0, 68.0, 90.0, 84.2];
}
