import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class BackendDocumentService {
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _authBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: '',
  );
  static const String _chatBaseUrl = String.fromEnvironment(
    'CHAT_BASE_URL',
    defaultValue: '',
  );
  static const String _streakBaseUrl = String.fromEnvironment(
    'STREAK_BASE_URL',
    defaultValue: '',
  );
  static const String _mockTestBaseUrl = String.fromEnvironment(
    'MOCKTEST_API_BASE_URL',
    defaultValue: '',
  );
  static const String _legacyMockTestBaseUrl = String.fromEnvironment(
    'MOCK_TEST_BASE_URL',
    defaultValue: '',
  );

  static String _clean(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://127.0.0.1:8000';
    return 'http://127.0.0.1:8000';
  }

  static List<String> _candidateBaseUrls() {
    final urls = <String>[];
    final explicit = <String>[
      _apiBaseUrl,
      _authBaseUrl,
      _chatBaseUrl,
      _streakBaseUrl,
      _mockTestBaseUrl,
      _legacyMockTestBaseUrl,
    ].where((value) => value.trim().isNotEmpty).map((value) => _clean(value.trim()));

    for (final candidate in explicit) {
      if (!urls.contains(candidate)) {
        urls.add(candidate);
      }
    }

    final platformDefault = _clean(_platformDefaultBaseUrl());
    if (!urls.contains(platformDefault)) {
      urls.add(platformDefault);
    }

    if (!urls.contains('http://10.0.2.2:8000')) {
      urls.add('http://10.0.2.2:8000');
    }

    if (!urls.contains('http://localhost:8000')) {
      urls.add('http://localhost:8000');
    }

    return urls;
  }

  static Uri syllabusUri({bool download = false}) {
    final baseUrl = _candidateBaseUrls().first;
    final uri = Uri.parse('$baseUrl/syllabus/neet.pdf');
    return download ? uri.replace(queryParameters: {'download': '1'}) : uri;
  }

  static Future<Uint8List> fetchSyllabusPdfBytes({bool download = false}) async {
    Object? lastError;

    for (final candidate in _candidateBaseUrls()) {
      try {
        final uri = Uri.parse('$candidate/syllabus/neet.pdf').replace(
          queryParameters: download ? {'download': '1'} : null,
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 20));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        }
        lastError = HttpException('HTTP ${response.statusCode}');
      } on Object catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'Cannot load syllabus PDF. Tried: ${_candidateBaseUrls().join(', ')}${lastError != null ? ' (${lastError.runtimeType})' : ''}',
    );
  }

  static Future<String> saveSyllabusPdf(Uint8List bytes) async {
    final directory = await _downloadDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}NEET_Syllabus.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<String> downloadSyllabusPdf({bool download = true}) async {
    final bytes = await fetchSyllabusPdfBytes(download: download);
    return saveSyllabusPdf(bytes);
  }

  static Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final downloadDirectories = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (downloadDirectories != null && downloadDirectories.isNotEmpty) {
        return downloadDirectories.first;
      }
    }

    return getApplicationDocumentsDirectory();
  }
}