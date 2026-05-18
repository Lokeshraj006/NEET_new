import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class MockQuestion {
  final String subject;
  final String unit;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String hash;

  const MockQuestion({required this.subject, required this.unit, required this.question, required this.options, required this.answerIndex, required this.explanation, required this.hash});

  static int _answerIndexFromJson(Map<String, dynamic> json) {
    final rawIndex = json['answer_index'];
    if (rawIndex is int) {
      return rawIndex.clamp(0, 3);
    }
    final rawLetter = (json['correct_answer'] ?? '').toString().trim().toUpperCase();
    if (rawLetter.length == 1 && rawLetter.codeUnitAt(0) >= 65 && rawLetter.codeUnitAt(0) <= 68) {
      return rawLetter.codeUnitAt(0) - 65;
    }
    return (int.tryParse('${rawIndex ?? 0}') ?? 0).clamp(0, 3).toInt();
  }

  static List<String> _optionsFromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    if (raw is Map) {
      return ['A', 'B', 'C', 'D'].map((key) => (raw[key] ?? '').toString()).toList();
    }
    if (raw is List) {
      return raw.map((e) => e.toString()).take(4).toList();
    }
    return const [];
  }

  factory MockQuestion.fromJson(Map<String, dynamic> json) => MockQuestion(
        subject: (json['subject'] ?? 'NEET').toString(),
        unit: (json['unit'] ?? '').toString(),
        question: (json['question'] ?? '').toString(),
        options: _optionsFromJson(json),
        answerIndex: _answerIndexFromJson(json),
        explanation: (json['explanation'] ?? '').toString(),
        hash: (json['hash'] ?? '').toString(),
      );
}

class MockTestBundle {
  final String sessionId;
  final List<MockQuestion> questions;
  final int attempt;
  final int attemptsAllowed;
  const MockTestBundle({required this.sessionId, required this.questions, required this.attempt, required this.attemptsAllowed});
}

class MockTestService {
  static const _seenKey = 'mock_test_seen_hashes';
  static const _sessionKey = 'mock_test_session_id';
  static const _envBaseUrl = String.fromEnvironment('MOCK_TEST_BASE_URL', defaultValue: '');
  static const _legacyChatBaseUrl = String.fromEnvironment('CHAT_BASE_URL', defaultValue: '');

  String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  String _clean(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  String _extractErrorMessage(String body, {String fallback = 'Request failed.'}) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {
      // Ignore malformed JSON and use the fallback message.
    }
    return fallback;
  }

  List<String> _candidateBaseUrls() {
    final explicit = _envBaseUrl.trim().isNotEmpty ? _envBaseUrl.trim() : _legacyChatBaseUrl.trim();
    final urls = <String>[_clean(explicit.isNotEmpty ? explicit : _platformDefaultBaseUrl())];
    const legacyIp = 'http://10.65.205.248:8000';

    final platformDefault = _clean(_platformDefaultBaseUrl());
    if (!urls.contains(platformDefault)) urls.add(platformDefault);
    if (!urls.contains(legacyIp)) urls.add(legacyIp);

    if (!kIsWeb && !Platform.isAndroid && !urls.contains('http://localhost:8000')) {
      urls.add('http://localhost:8000');
    }

    return urls;
  }

  Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> body,
    String token, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      final uri = Uri.parse('$candidate$path');
      try {
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ).timeout(timeout);
        if (response.statusCode == 200) {
          return response;
        }
        if (response.statusCode == 401) {
          await AuthService.logout();
          throw Exception(_extractErrorMessage(response.body, fallback: 'Your session expired. Please sign in again.'));
        }
        throw Exception(_extractErrorMessage(response.body, fallback: 'Server error (${response.statusCode}) from $candidate.'));
      } on http.ClientException catch (e) {
        lastConnectionError = e;
        continue;
      } on SocketException catch (e) {
        lastConnectionError = e;
        continue;
      } on TimeoutException {
        throw Exception('Server took too long to respond.');
      }
    }

    throw Exception(
      'Cannot reach mock-test server. Check backend and CHAT_BASE_URL or MOCK_TEST_BASE_URL. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
    );
  }

  Future<MockTestBundle> startFullMockTest({int count = 180}) async {
    final prefs = await _prefs;
    final seen = prefs.getStringList(_seenKey) ?? const [];
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before starting a mock test.');
    }
    final response = await _postWithFallback(
      '/mock-test/generate',
      {'count': count, 'exclude_hashes': seen},
      token,
      timeout: const Duration(seconds: 180),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final quiz = Map<String, dynamic>.from((data['quiz'] as Map?) ?? const {});
    final questionList = (data['questions'] as List? ?? quiz['questions'] as List? ?? const []);
    final questions = questionList.map((e) => MockQuestion.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final nextSessionId = (data['session_id'] ?? '').toString();
    if (nextSessionId.isNotEmpty) {
      await prefs.setString(_sessionKey, nextSessionId);
    }
    final attempt = int.tryParse('${data['attempt'] ?? quiz['attempt'] ?? 1}') ?? 1;
    final attemptsAllowed = int.tryParse('${data['attempts_allowed'] ?? quiz['attempts_allowed'] ?? 5}') ?? 5;
    final mergedSeen = {...seen, ...questions.map((q) => q.hash).where((e) => e.isNotEmpty)}.toList();
    await prefs.setStringList(_seenKey, mergedSeen);
    return MockTestBundle(sessionId: nextSessionId, questions: questions, attempt: attempt, attemptsAllowed: attemptsAllowed);
  }

  Future<void> preloadFullMockTest() async {
    return preloadFullMockTestEx(async: false, useFallback: false);
  }

  Future<void> preloadFullMockTestEx({bool async = false, bool useFallback = false}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before starting a mock test.');
    }
    final body = <String, dynamic>{'mode': async ? 'async' : 'now', 'use_fallback': useFallback};
    await _postWithFallback(
      '/mock-test/preload',
      body,
      token,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<Map<String, dynamic>> preloadStatus() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before checking preload status.');
    }
    final response = await _postWithFallback('/mock-test/preload/status', <String, dynamic>{}, token, timeout: const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<MockTestBundle> loadFixedSetBundle(int setId) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before opening a mock test set.');
    }
    final response = await _postWithFallback(
      '/mock-test/fixed-set/$setId',
      <String, dynamic>{},
      token,
      timeout: const Duration(seconds: 20),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['questions'] as List? ?? const []);
    final questions = items.map((entry) => MockQuestion.fromJson(Map<String, dynamic>.from(entry as Map))).toList();
    return MockTestBundle(
      sessionId: 'fixed_set_$setId',
      questions: questions,
      attempt: setId,
      attemptsAllowed: 1,
    );
  }

  Future<MockTestBundle> fetchQuestions({int count = 180}) async => startFullMockTest(count: count);

  Future<MockTestBundle> generateUnitQuiz({required String subject, required String topic}) async {
    final prefs = await _prefs;
    final sessionId = prefs.getString(_sessionKey);
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before starting a unit quiz.');
    }
    final response = await _postWithFallback(
      '/mock-test/unit/generate',
      {'subject': subject, 'unit': topic, 'topic': topic, 'session_id': sessionId},
      token,
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final quiz = Map<String, dynamic>.from((data['quiz'] as Map?) ?? const {});
    final questionList = (data['questions'] as List? ?? quiz['questions'] as List? ?? const []);
    final questions = questionList.map((e) => MockQuestion.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final nextSessionId = (data['session_id'] ?? sessionId ?? '').toString();
    final attempt = int.tryParse('${data['attempt'] ?? quiz['attempt'] ?? data['variant'] ?? 1}') ?? 1;
    final attemptsAllowed = int.tryParse('${data['attempts_allowed'] ?? quiz['attempts_allowed'] ?? 5}') ?? 5;
    await prefs.setString(_sessionKey, nextSessionId);
    return MockTestBundle(sessionId: nextSessionId, questions: questions, attempt: attempt, attemptsAllowed: attemptsAllowed);
  }

  Future<Map<String, dynamic>> submitAnswers({
    required String sessionId,
    required List<int?> answers,
    required Set<int> marked,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before submitting a mock test.');
    }
    final response = await _postWithFallback(
      '/mock-test/submit',
      {
        'session_id': sessionId,
        'answers': answers.map((value) => value).toList(),
        'marked': marked.toList(),
      },
      token,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitUnitQuiz({required String sessionId, required List<int?> answers, required Set<int> marked}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('You must sign in before submitting a unit quiz.');
    }
    final response = await _postWithFallback(
      '/mock-test/unit/submit',
      {
        'session_id': sessionId,
        'answers': answers.map((value) => value).toList(),
        'marked': marked.toList(),
      },
      token,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}