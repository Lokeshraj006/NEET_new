import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final ValueNotifier<String?> nameNotifier = ValueNotifier<String?>(
    null,
  );
  static final ValueNotifier<String?> emailNotifier = ValueNotifier<String?>(
    null,
  );
  static final ValueNotifier<String?> photoNotifier = ValueNotifier<String?>(
    null,
  );

  static const String _envBaseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: '',
  );

  static const String _envBaseUrlTypo = String.fromEnvironment(
    'AUTH_BASE_URl',
    defaultValue: '',
  );

  static const String _legacyChatBaseUrl = String.fromEnvironment(
    'CHAT_BASE_URL',
    defaultValue: '',
  );

  static String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String _clean(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static List<String> _candidateBaseUrls() {
    final explicit = _envBaseUrl.trim().isNotEmpty
        ? _envBaseUrl.trim()
        : _envBaseUrlTypo.trim().isNotEmpty
        ? _envBaseUrlTypo.trim()
        : _legacyChatBaseUrl.trim();
    final urls = <String>[
      _clean(explicit.isNotEmpty ? explicit : _platformDefaultBaseUrl()),
    ];
    const legacyIp = 'http://10.65.205.248:8000';
    final platformDefault = _clean(_platformDefaultBaseUrl());

    if (!urls.contains(platformDefault)) urls.add(platformDefault);
    if (!urls.contains(legacyIp)) urls.add(legacyIp);

    if (!kIsWeb &&
        !Platform.isAndroid &&
        !urls.contains('http://localhost:8000')) {
      urls.add('http://localhost:8000');
    }

    return urls;
  }

  static Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> payload, {
    Map<String, String> headers = const {},
  }) async {
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      try {
        return await http
            .post(
              Uri.parse('$candidate$path'),
              headers: {'Content-Type': 'application/json', ...headers},
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

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final res = await _postWithFallback('/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    final data = jsonDecode(res.body);
    if (res.statusCode != 200)
      throw Exception(data['detail'] ?? 'Registration failed.');
    await _saveSession(data);
    return data;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await _postWithFallback('/login', {
      'email': email,
      'password': password,
    });
    final data = jsonDecode(res.body);
    if (res.statusCode != 200)
      throw Exception(data['detail'] ?? 'Login failed.');
    await _saveSession(data);
    return data;
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? currentPassword,
    String? newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final payload = <String, dynamic>{
      'name': name,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'current_password': currentPassword,
      if (newPassword != null && newPassword.isNotEmpty)
        'new_password': newPassword,
    };

    final res = await _postWithFallback(
      '/profile',
      payload,
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200)
      throw Exception(data['detail'] ?? 'Profile update failed.');
    await _saveSession(data);
    return data;
  }

  static Future<String?> uploadPhoto(File photo) async {
    final email = await getEmail();
    if (email == null) return null;
    Object? lastConnectionError;
    for (final candidate in _candidateBaseUrls()) {
      try {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$candidate/upload-photo'),
        );
        req.fields['email'] = email;
        req.files.add(await http.MultipartFile.fromPath('photo', photo.path));
        final res = await req.send();
        final body = await res.stream.bytesToString();
        final data = jsonDecode(body);
        if (res.statusCode != 200)
          throw Exception(data['detail'] ?? 'Upload failed.');
        final photo64 = data['photo'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('photo', photo64);
        photoNotifier.value = photo64;
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
    if (data['photo'] != null) {
      await prefs.setString('photo', data['photo']);
    } else {
      await prefs.remove('photo');
    }
    nameNotifier.value = data['name'] as String?;
    emailNotifier.value = data['email'] as String?;
    photoNotifier.value = data['photo'] as String?;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    nameNotifier.value = null;
    emailNotifier.value = null;
    photoNotifier.value = null;
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
