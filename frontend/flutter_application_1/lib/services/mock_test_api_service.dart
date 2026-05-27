import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MockTestApiService {
  static const _envBaseUrl = String.fromEnvironment(
    'MOCKTEST_API_BASE_URL',
    defaultValue: '',
  );
  static const _legacyBaseUrl = String.fromEnvironment(
    'MOCK_TEST_BASE_URL',
    defaultValue: '',
  );
  static const _chatBaseUrl = String.fromEnvironment(
    'CHAT_BASE_URL',
    defaultValue: '',
  );
  static const _authBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: '',
  );

  String _clean(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  List<String> _candidateBaseUrls() {
    final explicit = _envBaseUrl.trim().isNotEmpty
        ? _envBaseUrl.trim()
        : _legacyBaseUrl.trim();
    final urls = <String>[
      _clean(explicit.isNotEmpty ? explicit : _platformDefaultBaseUrl()),
    ];
    final platformDefault = _clean(_platformDefaultBaseUrl());
    if (!urls.contains(platformDefault)) urls.add(platformDefault);
    for (final extra in [_chatBaseUrl, _authBaseUrl]) {
      final cleaned = extra.trim().isEmpty ? '' : _clean(extra.trim());
      if (cleaned.isNotEmpty && !urls.contains(cleaned)) urls.add(cleaned);
    }
    for (final fallback in const [
      'http://localhost:8000',
      'http://127.0.0.1:8000',
      'http://10.0.2.2:8000',
    ]) {
      if (!urls.contains(fallback)) urls.add(fallback);
    }
    return urls;
  }

  Future<List<Map<String, dynamic>>> fetchQuestions(
    int setNumber, {
    String? token,
  }) async {
    Object? lastError;
    for (final baseUrl in _candidateBaseUrls()) {
      final uri = Uri.parse('$baseUrl/mock-test/fixed-set/$setNumber');
      try {
        final headers = <String, String>{
          'Content-Type': 'application/json',
        };
        if (token != null && token.trim().isNotEmpty) {
          headers['Authorization'] = 'Bearer ${token.trim()}';
        }
        final response = await http.post(
          uri,
          headers: headers,
        ).timeout(
              const Duration(seconds: 30),
            );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final questions = data['questions'];
            if (questions is List) {
              return questions
                  .map((entry) => Map<String, dynamic>.from(entry as Map))
                  .toList(growable: false);
            }
          }
          if (data is List) {
            return data
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: false);
          }
          throw Exception('Unexpected response format from mock test API.');
        }
        if (response.statusCode == 401) {
          throw Exception('Please sign in again to open mock test sets.');
        }
        final message = _extractErrorMessage(response.body);
        if (response.statusCode == 404) {
          throw Exception(message);
        }
        throw Exception('Mock test API failed (${response.statusCode}): $message');
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'Cannot reach mock test API. Tried: ${_candidateBaseUrls().join(', ')}${lastError != null ? ' (${lastError.runtimeType})' : ''}. If you are on a physical phone, set MOCKTEST_API_BASE_URL to your PC IP.',
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // fallback below
    }
    return 'Request failed.';
  }
}
