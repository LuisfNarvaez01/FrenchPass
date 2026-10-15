import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/ai/ai_backend.dart';

AiException _from(String message) => AiException.from(Exception(message));

void main() {
  test('App Check and attestation failures are "unverified", not network', () {
    for (final message in [
      'PlatformException(firebase_app_check, Error returned from API. '
          'code: 403 body: App attestation failed.)',
      'ServerException: PERMISSION_DENIED: App Check token is invalid.',
    ]) {
      final e = _from(message);
      expect(e.issue, AiIssue.unverified, reason: message);
      expect(e.contactAdmin, isTrue, reason: message);
    }
  });

  test('Play Integrity codes map to what the learner can do', () {
    String integrity(int code) =>
        '[firebase_app_check/unknown] $code: Integrity API error ($code): '
        'something. (https://developer.android.com/...)';
    expect(_from(integrity(-3)).issue, AiIssue.network);
    expect(_from(integrity(-3)).transient, isTrue);
    expect(_from(integrity(-14)).issue, AiIssue.playServices);
    expect(_from(integrity(-15)).issue, AiIssue.playServices);
    expect(_from(integrity(-5)).issue, AiIssue.notFromPlay);
    expect(_from(integrity(-12)).issue, AiIssue.server);
    expect(_from(integrity(-16)).issue, AiIssue.setup);
  });

  test('a network failure gives steps, not a support address', () {
    final e = _from('[firebase_app_check/unknown] -3: Integrity API error '
        '(-3): Network error: unable to obtain integrity details.');
    expect(e.messageEs, contains('No pude conectar'));
    expect(e.messageEs, contains('VPN'));
    expect(e.messageEs, isNot(contains(AiException.supportEmail)));
  });

  test('our own setup problems ask the learner to write to us', () {
    const e = AiException(issue: AiIssue.setup);
    expect(e.unavailable, isTrue);
    expect(e.messageEs, contains('no está disponible'));
    expect(e.messageEs, contains(AiException.supportEmail));
  });

  test('quota and plain network errors keep their own message', () {
    expect(AiException.from(QuotaExceeded('slow down')).rateLimited, isTrue);
    final offline = _from('SocketException: Failed host lookup');
    expect(offline.issue, AiIssue.network);
    expect(offline.messageEs, contains('internet'));
  });

  test('the technical line is short enough for an error screen', () {
    final e = AiException(detail: 'x' * 500);
    expect(e.technicalEs.length, lessThan(200));
    expect(const AiException().technicalEs, isEmpty);
  });
}
