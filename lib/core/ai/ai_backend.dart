import 'dart:math';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:french_pass/core/config/app_channel.dart';
import 'package:french_pass/core/services/storage_service.dart';

/// Gemini, reached through Firebase AI Logic.
///
/// The app never holds a Gemini key: Firebase keeps it server-side and
/// accepts only requests carrying an App Check token, which on the Play
/// build comes from Play Integrity (a genuine, Play-installed copy of this
/// app). The GitHub build can't pass Play Integrity, so it uses App Check's
/// debug provider with a per-install token the developer registers once in
/// the Firebase console (shown in Settings).
abstract final class AiBackend {
  static bool _ready = false;
  static String? _debugToken;

  /// False when Firebase failed to start (no google-services.json in this
  /// build, or no network on first launch); AI features then say so instead
  /// of failing on every call.
  static bool get isReady => _ready;

  @visibleForTesting
  static set readyForTesting(bool ready) {
    _ready = ready;
    _testing = true;
  }

  /// Tests have no Firebase app to ask App Check.
  static bool _testing = false;

  /// The App Check debug token of this install, on builds that use one.
  static String? get debugToken => _debugToken;

  static Future<void> init(StorageService storage) async {
    try {
      await Firebase.initializeApp();
      final useDebug = AppChannel.isGithub || kDebugMode;
      if (useDebug) _debugToken = _debugTokenFor(storage);
      await FirebaseAppCheck.instance.activate(
        providerAndroid: useDebug
            ? AndroidDebugProvider(debugToken: _debugToken)
            : const AndroidPlayIntegrityProvider(),
      );
      _ready = true;
    } catch (e) {
      debugPrint('AiBackend.init failed: $e');
      _ready = false;
    }
  }

  static FirebaseAI get ai => FirebaseAI.googleAI();

  /// Asks App Check for a token before an AI call, so a copy that can't be
  /// verified says so instead of failing as if the network were down.
  /// Returns null when verified, else what went wrong.
  static Future<String?> verify() async {
    if (!_ready) return 'Firebase no se inició';
    if (_testing) return null;
    try {
      final token = await FirebaseAppCheck.instance
          .getToken()
          .timeout(const Duration(seconds: 15));
      return token == null || token.isEmpty ? 'App Check sin token' : null;
    } catch (e) {
      debugPrint('AiBackend.verify failed: $e');
      return '$e';
    }
  }

  /// A random UUID v4, kept for the life of the install so it only has to
  /// be registered in the console once.
  static String _debugTokenFor(StorageService storage) {
    final saved = storage.getString(StorageKeys.appCheckDebugToken);
    if (saved != null && saved.isNotEmpty) return saved;
    final token = uuidV4(Random.secure());
    storage.setString(StorageKeys.appCheckDebugToken, token);
    return token;
  }

  @visibleForTesting
  static String uuidV4(Random random) {
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

/// Why an AI call failed, worded once for every screen that makes one.
class AiException implements Exception {
  final bool rateLimited;
  final bool unavailable;

  /// App Check refused this copy of the app (Play Integrity, or an
  /// unregistered debug token on the GitHub build).
  final bool unverified;
  final String detail;

  const AiException({
    this.rateLimited = false,
    this.unavailable = false,
    this.unverified = false,
    this.detail = '',
  });

  /// Words that show up in App Check and attestation failures.
  static final _attestation = RegExp(
      r'app.?check|attestation|integrity|PERMISSION_DENIED|unauthenticated|'
      r'\b40[13]\b|too many attempts',
      caseSensitive: false);

  factory AiException.from(Object error) => switch (error) {
        AiException() => error,
        QuotaExceeded() => AiException(rateLimited: true, detail: '$error'),
        FirebaseAIException(:final message)
            when message.contains('RESOURCE_EXHAUSTED') ||
                message.contains('429') =>
          AiException(rateLimited: true, detail: message),
        ServiceApiNotEnabled() ||
        InvalidApiKey() =>
          AiException(unavailable: true, detail: '$error'),
        _ when _attestation.hasMatch('$error') =>
          AiException(unverified: true, detail: '$error'),
        _ => AiException(detail: '$error'),
      };

  /// The sentence the learner sees.
  String get messageEs => rateLimited
      ? 'Hay mucha gente usando la IA ahora mismo. Prueba en un minuto.'
      : unavailable
          ? 'La IA no está disponible en esta versión de la app. '
              'Actualízala desde Google Play.'
          : unverified
              ? (AppChannel.isGithub
                  ? 'Firebase no reconoce esta instalación. Registra el token '
                      'de App Check que aparece en Ajustes y vuelve a '
                      'intentarlo.'
                  : 'Google Play no pudo verificar esta copia de FrenchPass. '
                      'Instálala desde Google Play y vuelve a intentarlo.')
              : 'No pude conectar con la IA. Revisa tu conexión e inténtalo '
                  'otra vez.';

  /// One line for the error screen, so a failure can be reported exactly.
  String get technicalEs {
    final d = detail.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (d.isEmpty) return '';
    return 'Detalle técnico: ${d.length > 160 ? '${d.substring(0, 160)}…' : d}';
  }

  @override
  String toString() => 'AiException($detail)';
}
