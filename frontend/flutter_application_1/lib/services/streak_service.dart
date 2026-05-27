import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/services/auth_service.dart';

class DailyStreakQuestion {
  final String subject;
  final String unit;
  final String question;
  final List<String> options;
  final String hash;
  final int? answerIndex;
  final int? yourAnswerIndex;
  final bool? isCorrect;
  final String? explanation;

  const DailyStreakQuestion({
    required this.subject,
    required this.unit,
    required this.question,
    required this.options,
    required this.hash,
    this.answerIndex,
    this.yourAnswerIndex,
    this.isCorrect,
    this.explanation,
  });

  factory DailyStreakQuestion.fromJson(Map<String, dynamic> json) {
    return DailyStreakQuestion(
      subject: (json['subject'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      options: (json['options'] as List? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
      hash: (json['hash'] ?? '').toString(),
      answerIndex: json['answer_index'] == null ? null : int.tryParse('${json['answer_index']}'),
      yourAnswerIndex: json['your_answer_index'] == null ? null : int.tryParse('${json['your_answer_index']}'),
      isCorrect: json['is_correct'] is bool ? json['is_correct'] as bool : null,
      explanation: json['explanation']?.toString(),
    );
  }
}

class DailyStreakChallenge {
  final String date;
  final int streakDays;
  final int bestStreak;
  final bool submitted;
  final bool canAttempt;
  final bool completed;
  final int score;
  final int totalQuestions;
  final String message;
  final List<DailyStreakQuestion> questions;

  const DailyStreakChallenge({
    required this.date,
    required this.streakDays,
    required this.bestStreak,
    required this.submitted,
    required this.canAttempt,
    required this.completed,
    required this.score,
    required this.totalQuestions,
    required this.message,
    required this.questions,
  });

  factory DailyStreakChallenge.fromJson(Map<String, dynamic> json) {
    return DailyStreakChallenge(
      date: (json['date'] ?? '').toString(),
      streakDays: int.tryParse('${json['streak_days'] ?? 0}') ?? 0,
      bestStreak: int.tryParse('${json['best_streak'] ?? 0}') ?? 0,
      submitted: json['submitted'] == true,
      canAttempt: json['can_attempt'] != false,
      completed: json['completed'] == true,
      score: int.tryParse('${json['score'] ?? 0}') ?? 0,
      totalQuestions: int.tryParse('${json['total_questions'] ?? 0}') ?? 0,
      message: (json['message'] ?? '').toString(),
      questions: (json['questions'] as List? ?? const [])
          .map((entry) => DailyStreakQuestion.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }
}

class StreakService {
  static const String _envBaseUrl = String.fromEnvironment(
    'STREAK_BASE_URL',
    defaultValue: '',
  );

  static const String _legacyChatBaseUrl = String.fromEnvironment(
    'CHAT_BASE_URL',
    defaultValue: '',
  );

  String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  String _clean(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  List<String> _candidateBaseUrls() {
    final explicit = _envBaseUrl.trim().isNotEmpty ? _envBaseUrl.trim() : _legacyChatBaseUrl.trim();
    final urls = <String>[
      _clean(explicit.isNotEmpty ? explicit : _platformDefaultBaseUrl()),
    ];
    const legacyIp = 'http://10.65.205.248:8000';
    final platformDefault = _clean(_platformDefaultBaseUrl());

    if (!urls.contains(platformDefault)) urls.add(platformDefault);
    if (!urls.contains(legacyIp)) urls.add(legacyIp);
    if (!kIsWeb && !Platform.isAndroid && !urls.contains('http://localhost:8000')) {
      urls.add('http://localhost:8000');
    }
    return urls;
  }

  Future<http.Response> _requestWithFallback(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      final uri = Uri.parse('$candidate$path');
      try {
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final request = method == 'GET'
            ? http.get(uri, headers: headers)
            : http.post(uri, headers: headers, body: jsonEncode(body ?? const {}));
        final response = await request.timeout(timeout);
        if (response.statusCode == 401) {
          await AuthService.logout();
          throw Exception('Your session expired. Please sign in again.');
        }
        if (response.statusCode >= 400) {
          String? message;
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['detail'] != null) {
              message = data['detail'].toString();
            }
          } catch (_) {
            // Fall back to the generic message below.
          }
          throw Exception(message ?? 'Server error (${response.statusCode}) from $candidate.');
        }
        return response;
      } on SocketException catch (e) {
        lastConnectionError = e;
        continue;
      }
    }

    throw Exception(
      'Cannot reach streak server. Check backend and STREAK_BASE_URL. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
    );
  }

  Future<DailyStreakChallenge> fetchToday() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before opening the daily streak.');
    }
    final response = await _requestWithFallback('GET', '/streak/today', token);
    return DailyStreakChallenge.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<DailyStreakChallenge> submitToday({required List<int?> answers}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before submitting the daily streak.');
    }
    final response = await _requestWithFallback(
      'POST',
      '/streak/today/submit',
      token,
      body: {'answers': answers},
      timeout: const Duration(seconds: 45),
    );
    return DailyStreakChallenge.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }
}