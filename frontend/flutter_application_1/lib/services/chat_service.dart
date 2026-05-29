import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/widgets/chat_message.dart';

class ChatService {
  // Override with: flutter run --dart-define=CHAT_BASE_URL=http://<pc-ip>:8000
  static const String _envBaseUrl = String.fromEnvironment(
    'CHAT_BASE_URL',
    defaultValue: '',
  );

  static String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  final String baseUrl;

  ChatService({String? baseUrl})
      : baseUrl =
            (baseUrl ?? _envBaseUrl).trim().isNotEmpty ? (baseUrl ?? _envBaseUrl).trim() : _platformDefaultBaseUrl();

  String _clean(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  List<String> _candidateBaseUrls() {
    final urls = <String>[_clean(baseUrl)];
    const legacyIp = 'http://10.65.205.248:8000';
    final platformDefault = _clean(_platformDefaultBaseUrl());

    if (!urls.contains(platformDefault)) urls.add(platformDefault);
    if (!urls.contains(legacyIp)) urls.add(legacyIp);

    if (!kIsWeb && !Platform.isAndroid && !urls.contains('http://localhost:8000')) {
      urls.add('http://localhost:8000');
    }

    return urls;
  }

  Future<Map<String, dynamic>> sendMessage(
    String message, {
    List<ChatMessageModel>? history,
    String? sessionId,
    bool detailed = false,
  }) async {
    final body = {
      'message': message,
      'history': history?.map((m) => {'role': m.isUser ? 'user' : 'bot', 'text': m.text}).toList() ?? [],
      'session_id': sessionId,
      'detailed': detailed,
    };
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      final uri = Uri.parse('$candidate/chat');
      try {
        final res = await http
          .post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 120));
        if (res.statusCode != 200) {
          throw Exception('Server error (${res.statusCode}) from $candidate.');
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data;
      } on SocketException catch (e) {
        lastConnectionError = e;
        continue;
      } on TimeoutException {
        throw Exception('Server took too long to respond.');
      } on FormatException {
        throw Exception('Invalid response from server.');
      }
    }

    throw Exception(
      'Cannot reach chat server. Check backend and CHAT_BASE_URL. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
    );
  }
}
