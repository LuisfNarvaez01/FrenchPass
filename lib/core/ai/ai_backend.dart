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
  static set readyForTesting(bool ready) => _ready = ready;

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
  final String detail;

  const AiException({
    this.rateLimited = false,
    this.unavailable = false,
    this.detail = '',
  });

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
        _ => AiException(detail: '$error'),
      };

  /// The sentence the learner sees.
  String get messageEs => rateLimited
      ? 'Hay mucha gente usando la IA ahora mismo. Prueba en un minuto.'
      : unavailable
          ? 'La IA no está disponible en esta versión de la app. '
              'Actualízala desde Google Play.'
          : 'No pude conectar con la IA. Revisa tu conexión e inténtalo '
              'otra vez.';

  @override
  String toString() => 'AiException($detail)';
}
