import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/sound_service.dart';

void main() {
  test('every sound is short, audible and never clips', () {
    for (final sound in AppSound.values) {
      final pcm = SoundService.synthesize(sound);
      // 24 kHz mono: under a second each, so a sound never lingers.
      expect(pcm.length, inInclusiveRange(2400, 24000), reason: sound.name);
      final peak = pcm.fold<int>(0, (m, v) => v.abs() > m ? v.abs() : m);
      expect(peak, greaterThan(3000), reason: sound.name);
      expect(peak, lessThan(32767 * 0.3), reason: sound.name);
    }
  });
}
