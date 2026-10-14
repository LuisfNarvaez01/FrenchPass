import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/ai/ai_backend.dart';

void main() {
  test('App Check and attestation failures are "unverified", not network', () {
    for (final message in [
      'PlatformException(firebase_app_check, Error returned from API. '
          'code: 403 body: App attestation failed.)',
      'ServerException: PERMISSION_DENIED: App Check token is invalid.',
      'Too many attempts.',
      'Integrity API error (-9): App not installed by Play.',
    ]) {
      final e = AiException.from(Exception(message));
      expect(e.unverified, isTrue, reason: message);
      expect(e.messageEs, isNot(contains('conexión')), reason: message);
    }
  });

  test('quota and plain network errors keep their own message', () {
    expect(AiException.from(QuotaExceeded('slow down')).rateLimited, isTrue);
    final offline =
        AiException.from(Exception('SocketException: Failed host lookup'));
    expect(offline.unverified, isFalse);
    expect(offline.messageEs, contains('conexión'));
  });

  test('the technical line is short enough for an error screen', () {
    final e = AiException(detail: 'x' * 500);
    expect(e.technicalEs.length, lessThan(200));
    expect(const AiException().technicalEs, isEmpty);
  });
}
