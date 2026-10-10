import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('a higher patch version is newer', () {
      expect(UpdateService.isNewerVersion('1.1.1', '1.1.0'), isTrue);
    });

    test('a higher minor version is newer even with a lower patch', () {
      expect(UpdateService.isNewerVersion('1.2.0', '1.1.9'), isTrue);
    });

    test('an equal version is not newer', () {
      expect(UpdateService.isNewerVersion('1.1.0', '1.1.0'), isFalse);
    });

    test('an older version is not newer', () {
      expect(UpdateService.isNewerVersion('1.0.9', '1.1.0'), isFalse);
    });

    test('ignores the build-number suffix after "+"', () {
      expect(UpdateService.isNewerVersion('1.1.0+9', '1.1.0+2'), isFalse);
      expect(UpdateService.isNewerVersion('1.2.0+1', '1.1.0+99'), isTrue);
    });

    test('a shorter version string is padded with zeros', () {
      expect(UpdateService.isNewerVersion('1.2', '1.1.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.1', '1.1.0'), isFalse);
    });

    test('a malformed segment is treated as zero rather than throwing', () {
      expect(UpdateService.isNewerVersion('1.x.0', '1.0.0'), isFalse);
    });
  });
}
