import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _envBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: '',
  );

  static String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String _clean(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static List<String> _candidateBaseUrls() {
    final urls = <String>[
      _clean(_envBaseUrl.trim().isNotEmpty ? _envBaseUrl.trim() : _platformDefaultBaseUrl()),
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

  static Future<http.Response> _postWithFallback(String path, Map<String, dynamic> payload) async {
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      try {
        return await http
            .post(
              Uri.parse('$candidate$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 60));
      } on SocketException catch (e) {
        lastConnectionError = e;
        continue;
      }
    }

    throw Exception(
      'Cannot reach auth server. Check backend and AUTH_BASE_URL. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
    );
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final res = await _postWithFallback('/register', {'name': name, 'email': email, 'password': password});
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(data['detail'] ?? 'Registration failed.');
    await _saveSession(data);
    return data;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _postWithFallback('/login', {'email': email, 'password': password});
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(data['detail'] ?? 'Login failed.');
    await _saveSession(data);
    return data;
  }

  static Future<String?> uploadPhoto(File photo) async {
    final email = await getEmail();
    if (email == null) return null;
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      try {
        final req = http.MultipartRequest('POST', Uri.parse('$candidate/upload-photo'));
        req.fields['email'] = email;
        req.files.add(await http.MultipartFile.fromPath('photo', photo.path));
        final res = await req.send();
        final body = await res.stream.bytesToString();
        final data = jsonDecode(body);
        if (res.statusCode != 200) throw Exception(data['detail'] ?? 'Upload failed.');
        final photo64 = data['photo'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('photo', photo64);
        return photo64;
      } on SocketException catch (e) {
        lastConnectionError = e;
        continue;
      }
    }

    throw Exception(
      'Cannot reach auth server. Check backend and AUTH_BASE_URL. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
    );
  }

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token'] ?? '');
    await prefs.setString('name', data['name'] ?? '');
    await prefs.setString('email', data['email'] ?? '');
    if (data['photo'] != null) await prefs.setString('photo', data['photo']);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  static Future<String?> getPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('photo');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
