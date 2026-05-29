import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  final String? idToken;
  final String? accessToken;
  final String? name;
  final String? email;
  final String? photoUrl;

  const GoogleAuthResult({
    required this.idToken,
    required this.accessToken,
    required this.name,
    required this.email,
    required this.photoUrl,
  });
}

class GoogleAuthService {
  static const String _defaultWebClientId =
      '900065986411-1ts210k09li81attvcntq2b33ppfhc9a.apps.googleusercontent.com';

  static const String _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Use the web client ID when running on web.
    clientId: kIsWeb && _webClientId.isNotEmpty ? _webClientId : null,
    // On Android/iOS, the server client ID should be the web OAuth client ID.
    serverClientId: !kIsWeb && _webClientId.isNotEmpty ? _webClientId : null,
    scopes: const ['openid', 'email', 'profile'],
  );

  static Future<GoogleAuthResult?> signIn() async {
    if (_webClientId.isEmpty) {
      throw Exception('Google web client ID is not configured.');
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authentication = await account.authentication;
      return GoogleAuthResult(
        idToken: authentication.idToken,
        accessToken: authentication.accessToken,
        name: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled') return null;
      throw Exception(_readableError(error.message));
    } catch (error) {
      final message = _readableError(error.toString());
      if (message.contains('ApiException: 10')) {
        throw Exception(
          'Google sign-in is not configured for this Android app yet. '
          'Make sure the app package name and SHA-1 fingerprint are added to '
          'your Google/Firebase project, then download the updated Android config.',
        );
      }
      throw Exception(message);
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  static String _readableError(String? message) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Google sign-in failed. Please try again.';
    }
    return trimmed;
  }
}
