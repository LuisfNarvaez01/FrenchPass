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
  /// verified says why instead of failing as if the network were down.
  /// Network hiccups are retried twice. Returns null when verified.
  static Future<AiException?> verify() async {
    if (!_ready) {
      return const AiException(
          issue: AiIssue.setup, detail: 'Firebase no se inició');
    }
    if (_testing) return null;
    AiException? problem;
    for (final wait in const [
      Duration.zero,
      Duration(seconds: 1),
      Duration(seconds: 3),
    ]) {
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        final token = await FirebaseAppCheck.instance
            .getToken()
            .timeout(const Duration(seconds: 15));
        if (token != null && token.isNotEmpty) return null;
        problem = const AiException(detail: 'App Check sin token');
      } catch (e) {
        debugPrint('AiBackend.verify failed: $e');
        problem = AiException.from(e);
        if (!problem.transient) return problem;
      }
    }
    return problem;
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

/// What went wrong with an AI call, as far as the learner is concerned.
enum AiIssue {
  /// Too many people on the shared Gemini quota right now.
  rateLimited,

  /// The phone couldn't reach Google: no signal, a VPN, a DNS blocker.
  network,

  /// Play Store or Google Play services are missing, outdated or signed out.
  playServices,

  /// This copy wasn't installed from Google Play.
  notFromPlay,

  /// Google wouldn't vouch for this phone or this copy: a rooted phone, a
  /// modified system, or our App Check setup.
  unverified,

  /// Google's side failed or is throttling; it passes on its own.
  server,

  /// Our setup is broken (no Firebase config, API off, bad project). Only
  /// the developer can fix it.
  setup,

  unknown,
}

/// Why an AI call failed, worded once for every screen that makes one.
///
/// The learner gets a sentence and steps they can try themselves; the raw
/// error appears only on the developer's builds.
class AiException implements Exception {
  final AiIssue issue;
  final String detail;

  const AiException({this.issue = AiIssue.unknown, this.detail = ''});

  static const supportEmail = 'frenchpass07@gmail.com';

  bool get rateLimited => issue == AiIssue.rateLimited;
  bool get unavailable => issue == AiIssue.setup;
  bool get unverified =>
      issue == AiIssue.unverified || issue == AiIssue.notFromPlay;

  /// Worth retrying by itself a moment later.
  bool get transient => issue == AiIssue.network || issue == AiIssue.server;

  /// Play Integrity reports failures as "Integrity API error (-N)".
  static final _integrityCode =
      RegExp(r'Integrity API error \((-?\d+)\)', caseSensitive: false);

  /// Words that show up in App Check and attestation failures.
  static final _attestation = RegExp(
      r'app.?check|attestation|integrity|PERMISSION_DENIED|unauthenticated|'
      r'\b40[13]\b',
      caseSensitive: false);

  static final _server = RegExp(
      r'too many attempts|\b50[0234]\b|\bUNAVAILABLE\b|\bINTERNAL\b|'
      r'DEADLINE_EXCEEDED',
      caseSensitive: false);

  static final _network = RegExp(
      r'SocketException|host lookup|network|connection|timed? ?out|'
      r'TimeoutException|handshake|unreachable',
      caseSensitive: false);

  factory AiException.from(Object error) {
    if (error is AiException) return error;
    final text = '$error';
    AiException as(AiIssue issue) => AiException(issue: issue, detail: text);
    if (error is QuotaExceeded ||
        (error is FirebaseAIException &&
            (error.message.contains('RESOURCE_EXHAUSTED') ||
                error.message.contains('429')))) {
      return as(AiIssue.rateLimited);
    }
    if (error is ServiceApiNotEnabled || error is InvalidApiKey) {
      return as(AiIssue.setup);
    }
    final code = _integrityCode.firstMatch(text)?.group(1);
    if (code != null) return as(_integrityIssue(int.parse(code)));
    if (_attestation.hasMatch(text)) return as(AiIssue.unverified);
    if (_server.hasMatch(text)) return as(AiIssue.server);
    if (_network.hasMatch(text)) return as(AiIssue.network);
    return as(AiIssue.unknown);
  }

  /// Play Integrity's client error codes, from
  /// developer.android.com/google/play/integrity/reference/com/google/android/play/core/integrity/model/IntegrityErrorCode
  static AiIssue _integrityIssue(int code) => switch (code) {
        -3 => AiIssue.network,
        -1 || -2 || -4 || -6 || -9 || -14 || -15 => AiIssue.playServices,
        -5 || -7 => AiIssue.notFromPlay,
        -8 || -12 || -100 => AiIssue.server,
        // -10, -11, -13, -16, -17: the request itself is wrong.
        _ => AiIssue.setup,
      };

  /// The raw error belongs on the developer's builds only.
  static bool get _showTechnical => AppChannel.isGithub || kDebugMode;

  /// One sentence on what happened.
  String get headlineEs => switch (issue) {
        AiIssue.rateLimited => 'Hay mucha gente usando la IA ahora mismo.',
        AiIssue.network => 'No pude conectar con la IA.',
        AiIssue.playServices =>
          'Tu teléfono necesita poner al día Google Play.',
        AiIssue.notFromPlay =>
          'Esta copia de FrenchPass no se instaló desde Google Play.',
        AiIssue.unverified => AppChannel.isGithub
            ? 'Firebase no reconoce esta instalación.'
            : 'Google no pudo verificar este teléfono.',
        AiIssue.server => 'Los servidores de Google no respondieron.',
        AiIssue.setup =>
          'La IA no está disponible ahora por un problema de nuestra parte.',
        AiIssue.unknown => 'Algo falló al hablar con la IA.',
      };

  /// What the learner can try, in order.
  List<String> get stepsEs => switch (issue) {
        AiIssue.rateLimited => const [
            'Espera un minuto y vuelve a intentarlo.',
          ],
        AiIssue.network => const [
            'Comprueba que tienes internet. Si puedes, cambia de Wi-Fi a '
                'datos o al revés.',
            'Si usas una VPN, un DNS privado o un bloqueador de anuncios, '
                'desactívalo un momento.',
            'Revisa que Play Store y Servicios de Google Play no tengan los '
                'datos bloqueados por el ahorro de datos.',
          ],
        AiIssue.playServices => const [
            'Abre Play Store, toca tu foto › Ajustes › Información › '
                'Actualizar Play Store.',
            'Busca «Servicios de Google Play» en Play Store y actualízalo.',
            'Comprueba que tienes una cuenta de Google abierta en Play Store.',
            'Reinicia el teléfono y vuelve a intentarlo.',
          ],
        AiIssue.notFromPlay => const [
            'Desinstala FrenchPass e instálala desde Google Play.',
          ],
        AiIssue.unverified => AppChannel.isGithub
            ? const [
                'Registra en Firebase el token de App Check que aparece en '
                    'Ajustes y vuelve a intentarlo.',
              ]
            : const [
                'Actualiza Play Store y Servicios de Google Play.',
                'Reinicia el teléfono y vuelve a intentarlo.',
                'La IA no funciona en teléfonos con root, con el bootloader '
                    'desbloqueado o con un sistema modificado.',
              ],
        AiIssue.server => const ['Vuelve a intentarlo en unos minutos.'],
        AiIssue.setup => const [
            'Cierra la app por completo y vuelve a abrirla.',
          ],
        AiIssue.unknown => const [
            'Comprueba tu conexión y vuelve a intentarlo.',
          ],
      };

  /// Failures that are, or may be, ours to fix.
  bool get contactAdmin => switch (issue) {
        AiIssue.setup || AiIssue.unknown => true,
        AiIssue.unverified => !AppChannel.isGithub,
        _ => false,
      };

  /// Everything the learner sees: what happened, what to try, and who to
  /// write to when the fix may be ours.
  String get messageEs {
    final steps = stepsEs;
    return [
      headlineEs,
      if (steps.length == 1)
        steps.single
      else
        'Prueba esto:\n${steps.map((s) => '• $s').join('\n')}',
      if (contactAdmin)
        'Si sigue sin funcionar, escríbenos a $supportEmail y lo '
            'revisamos.',
      if (_showTechnical && technicalEs.isNotEmpty) technicalEs,
    ].join('\n\n');
  }

  /// The raw error in one line, for the developer's builds.
  String get technicalEs {
    final d = detail.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (d.isEmpty) return '';
    return 'Detalle técnico: ${d.length > 160 ? '${d.substring(0, 160)}…' : d}';
  }

  @override
  String toString() => 'AiException(${issue.name}: $detail)';
}
