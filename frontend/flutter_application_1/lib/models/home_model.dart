import 'package:flutter/material.dart';

import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/streak_service.dart';

class HomeModel extends ChangeNotifier {
  final StreakService _streakService = StreakService();

  int selectedIndex = 0;
  bool isLoadingDaily = true;
  String? dailyError;
  DailyStreakChallenge? dailyChallenge;

  HomeModel() {
    _loadDailyChallenge();
  }

  void setIndex(int i) {
    selectedIndex = i;
    notifyListeners();
  }

  Future<void> _loadDailyChallenge() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      isLoadingDaily = false;
      dailyChallenge = null;
      dailyError = null;
      notifyListeners();
      return;
    }
    try {
      dailyError = null;
      dailyChallenge = await _streakService.fetchToday();
    } catch (error) {
      dailyError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingDaily = false;
      notifyListeners();
    }
  }

  Future<void> refreshDailyChallenge() async {
    isLoadingDaily = true;
    notifyListeners();
    await _loadDailyChallenge();
  }

  void applyDailyChallenge(DailyStreakChallenge challenge) {
    dailyChallenge = challenge;
    dailyError = null;
    isLoadingDaily = false;
    notifyListeners();
  }

  int get streakDays => dailyChallenge?.streakDays ?? 0;

  int get bestStreak => dailyChallenge?.bestStreak ?? 0;

  bool get dailyCompleted => dailyChallenge?.submitted == true;

  String get quote {
    if (streakDays == 0) {
      return 'Three questions a day. One flame to build.';
    }
    if (dailyCompleted) {
      return 'Flame held. Come back tomorrow to keep the run alive.';
    }
    return 'One shot today. Solve all 3 to grow the streak.';
  }

  String get dailyStatusText {
    if (isLoadingDaily) return 'Loading today\'s arena...';
    if (dailyError != null) return dailyError!;
    if (dailyChallenge == null) return 'Daily arena unavailable.';
    if (dailyChallenge!.submitted) return 'Locked for today';
    return '3 quests ready';
  }

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

  Map<String, dynamic> get problemOfDay {
    final challenge = dailyChallenge;
    if (challenge != null && challenge.questions.isNotEmpty) {
      final question = challenge.questions.first;
      return {
        'subject': question.subject,
        'question': question.question,
        'options': question.options,
        'answerIndex': question.answerIndex,
      };
    }

    return {
      'subject': 'Physics',
      'question': 'A ray of light passes from air into glass. What happens to its speed?',
      'options': ['Increases', 'Decreases', 'Remains same', 'Becomes zero'],
      'answerIndex': 1,
    };
  }

  final accuracyValues = [60.0, 70.0, 68.0, 90.0, 84.2];
}
