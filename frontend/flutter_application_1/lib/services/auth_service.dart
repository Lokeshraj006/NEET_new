import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/google_auth_service.dart';

class AuthService {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const String _authWorkingBaseUrlKey = 'auth_working_base_url';
  static const String _legacyWorkingBaseUrlKey = 'working_base_url';

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

  static const String _mockTestBaseUrl = String.fromEnvironment(
    'MOCK_TEST_BASE_URL',
    defaultValue: '',
  );

  static const String _streakBaseUrl = String.fromEnvironment(
    'STREAK_BASE_URL',
    defaultValue: '',
  );

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _resolvedBaseUrl;

  static String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String _clean(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static List<String> _candidateBaseUrls() {
    final explicitCandidates = <String>[
      _envBaseUrl.trim(),
      _envBaseUrlTypo.trim(),
      _apiBaseUrl.trim(),
      _streakBaseUrl.trim(),
      _mockTestBaseUrl.trim(),
      _legacyChatBaseUrl.trim(),
    ].where((value) => value.isNotEmpty).map(_clean).toList();
    final urls = <String>[];

    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.trim().isNotEmpty) {
      urls.add(_clean(_resolvedBaseUrl!.trim()));
    }

    if (explicitCandidates.isNotEmpty) {
      for (final candidate in explicitCandidates) {
        if (!urls.contains(candidate)) {
          urls.add(candidate);
        }
      }
    } else {
      urls.add(_clean(_platformDefaultBaseUrl()));
    }

    final platformDefault = _clean(_platformDefaultBaseUrl());

    if (!urls.contains(platformDefault)) urls.add(platformDefault);

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
    Duration timeout = _requestTimeout,
  }) async {
    Object? lastConnectionError;

    // Prefer a previously discovered working base URL persisted across runs.
    final prefs = await SharedPreferences.getInstance();
    if (_resolvedBaseUrl == null) {
      final stored = prefs.getString(_authWorkingBaseUrlKey);
      final legacyStored = prefs.getString(_legacyWorkingBaseUrlKey);
      final selectedStored = (stored != null && stored.trim().isNotEmpty)
          ? stored
          : legacyStored;
      if (selectedStored != null && selectedStored.trim().isNotEmpty) {
        _resolvedBaseUrl = _clean(selectedStored.trim());
      }
    }

    for (final candidate in _candidateBaseUrls()) {
      try {
        developer.log('Auth POST start', name: 'AuthService', error: {'candidate': candidate, 'path': path});
        final response = await http
            .post(
              Uri.parse('$candidate$path'),
              headers: {'Content-Type': 'application/json', ...headers},
              body: jsonEncode(payload),
            )
            .timeout(timeout);
        _resolvedBaseUrl = candidate;
        await prefs.setString(_authWorkingBaseUrlKey, candidate);
        developer.log('Auth POST success', name: 'AuthService', error: {'candidate': candidate, 'path': path, 'statusCode': response.statusCode});
        return response;
      } on SocketException catch (e) {
        developer.log('Auth POST socket error', name: 'AuthService', error: {'candidate': candidate, 'path': path, 'error': e.toString()});
        lastConnectionError = e;
        continue;
      } on TimeoutException catch (e) {
        developer.log('Auth POST timeout', name: 'AuthService', error: {'candidate': candidate, 'path': path, 'error': e.toString(), 'timeoutSeconds': timeout.inSeconds});
        lastConnectionError = e;
        continue;
      } on http.ClientException catch (e) {
        developer.log('Auth POST client error', name: 'AuthService', error: {'candidate': candidate, 'path': path, 'error': e.toString()});
        lastConnectionError = e;
        continue;
      }
    }

    throw Exception(
      'Cannot reach auth server. Check backend and AUTH_BASE_URL. '
      'If you are on a physical Android phone, set AUTH_BASE_URL to your PC IP, '
      'for example http://192.168.x.x:8000. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
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
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Registration failed.');
    }
    await _saveSession(data);
    return data;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return _submitAuth('/login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String token) async {
    return _submitAuth(
      '/login/google',
      {'token': token},
      timeout: const Duration(seconds: 20),
    );
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
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Profile update failed.');
    }
    await _saveSession(data);
    return data;
  }

  static Future<Map<String, dynamic>> _submitAuth(
    String path,
    Map<String, dynamic> payload, {
    Map<String, String> headers = const {},
    Duration timeout = _requestTimeout,
  }) async {
    final res = await _postWithFallback(
      path,
      payload,
      headers: headers,
      timeout: timeout,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Login failed.');
    }
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
        if (res.statusCode != 200) {
          throw Exception(data['detail'] ?? 'Upload failed.');
        }
        final photo64 = data['photo'] as String;
        _resolvedBaseUrl = candidate;
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
      'Cannot reach auth server. Check backend and AUTH_BASE_URL. '
      'If you are on a physical Android phone, set AUTH_BASE_URL to your PC IP, '
      'for example http://192.168.x.x:8000. Tried: ${_candidateBaseUrls().join(', ')}${lastConnectionError != null ? ' (${lastConnectionError.runtimeType})' : ''}',
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

    // Proactively warm server caches and rotation pools so quizzes are instant.
    // Runs in background; failures are ignored.
    unawaited(_backgroundPrefill());
  }

  static Future<void> _backgroundPrefill() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;
      final headers = {'Authorization': 'Bearer $token'};

      // Prime mock-test cache (async, fallback-only for speed).
      try {
        await _postWithFallback(
          '/mock-test/preload',
          {'mode': 'async', 'use_fallback': true},
          headers: headers,
        );
      } catch (_) {}

      // Prefill a small set of high-traffic units; each call is async on the server.
      final unitsToPrefill = <Map<String, String>>[
        // Physics
        {'subject': 'Physics', 'unit': 'Physics and Measurement'},
        {'subject': 'Physics', 'unit': 'Kinematics'},
        {'subject': 'Physics', 'unit': 'Laws of Motion'},
        {'subject': 'Physics', 'unit': 'Work, Energy and Power'},
        {'subject': 'Physics', 'unit': 'Rotational Motion'},
        {'subject': 'Physics', 'unit': 'Gravitation'},
        {'subject': 'Physics', 'unit': 'Properties of Solids and Liquids'},
        {'subject': 'Physics', 'unit': 'Thermodynamics'},
        {'subject': 'Physics', 'unit': 'Kinetic Theory of Gases'},
        {'subject': 'Physics', 'unit': 'Oscillations and Waves'},
        {'subject': 'Physics', 'unit': 'Electrostatics'},
        {'subject': 'Physics', 'unit': 'Current Electricity'},
        {'subject': 'Physics', 'unit': 'Magnetic Effects of Current and Magnetism'},
        {'subject': 'Physics', 'unit': 'Electromagnetic Induction and Alternating Currents'},
        {'subject': 'Physics', 'unit': 'Electromagnetic Waves'},
        {'subject': 'Physics', 'unit': 'Optics'},
        {'subject': 'Physics', 'unit': 'Dual Nature of Matter and Radiation'},
        {'subject': 'Physics', 'unit': 'Atoms and Nuclei'},
        {'subject': 'Physics', 'unit': 'Electronic Devices'},
        // Chemistry - Physical
        {'subject': 'Chemistry', 'unit': 'Some Basic Concepts in Chemistry'},
        {'subject': 'Chemistry', 'unit': 'Atomic Structure'},
        {'subject': 'Chemistry', 'unit': 'Chemical Bonding and Molecular Structure'},
        {'subject': 'Chemistry', 'unit': 'Chemical Thermodynamics'},
        {'subject': 'Chemistry', 'unit': 'Equilibrium'},
        {'subject': 'Chemistry', 'unit': 'Solutions'},
        {'subject': 'Chemistry', 'unit': 'Redox Reactions and Electrochemistry'},
        {'subject': 'Chemistry', 'unit': 'Chemical Kinetics'},
        // Chemistry - Inorganic
        {'subject': 'Chemistry', 'unit': 'Classification of Elements and Periodicity in Properties'},
        {'subject': 'Chemistry', 'unit': 'P-Block Elements'},
        {'subject': 'Chemistry', 'unit': 'd- and f-Block Elements'},
        {'subject': 'Chemistry', 'unit': 'Co-ordination Compounds'},
        // Chemistry - Organic
        {'subject': 'Chemistry', 'unit': 'Purification and Characterisation of Organic Compounds'},
        {'subject': 'Chemistry', 'unit': 'Some Basic Principles of Organic Chemistry'},
        {'subject': 'Chemistry', 'unit': 'Hydrocarbons'},
        {'subject': 'Chemistry', 'unit': 'Organic Compounds Containing Halogens'},
        {'subject': 'Chemistry', 'unit': 'Organic Compounds Containing Oxygen'},
        {'subject': 'Chemistry', 'unit': 'Organic Compounds Containing Nitrogen'},
        {'subject': 'Chemistry', 'unit': 'Biomolecules'},
        {'subject': 'Chemistry', 'unit': 'Principles Related to Practical Chemistry'},
        // Biology
        {'subject': 'Biology', 'unit': 'Diversity in Living World'},
        {'subject': 'Biology', 'unit': 'Structural Organisation in Animals and Plants'},
        {'subject': 'Biology', 'unit': 'Cell Structure and Function'},
        {'subject': 'Biology', 'unit': 'Plant Physiology'},
        {'subject': 'Biology', 'unit': 'Human Physiology'},
        {'subject': 'Biology', 'unit': 'Reproduction'},
        {'subject': 'Biology', 'unit': 'Genetics and Evolution'},
        {'subject': 'Biology', 'unit': 'Biology and Human Welfare'},
        {'subject': 'Biology', 'unit': 'Biotechnology and Its Applications'},
        {'subject': 'Biology', 'unit': 'Ecology and Environment'},
      ];

      const int size = 50;
      const int maxUnits = 6;
      for (final u in unitsToPrefill.take(maxUnits)) {
        try {
          await _postWithFallback(
            '/mock-test/unit/prefill?mode=async&size=$size',
            {
              'subject': u['subject'],
              'unit': u['unit'],
            },
            headers: headers,
            timeout: const Duration(seconds: 8),
          );
        } catch (_) {}
      }
    } catch (_) {
      // ignore all background prefill errors
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  static Future<void> logout() async {
    await GoogleAuthService.signOut();
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
