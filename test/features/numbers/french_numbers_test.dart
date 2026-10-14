import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/numbers/domain/french_numbers.dart';

void main() {
  group('toWords', () {
    final cases = {
      0: 'zéro',
      7: 'sept',
      16: 'seize',
      17: 'dix-sept',
      21: 'vingt et un',
      22: 'vingt-deux',
      40: 'quarante',
      61: 'soixante et un',
      70: 'soixante-dix',
      71: 'soixante et onze',
      77: 'soixante-dix-sept',
      80: 'quatre-vingts',
      81: 'quatre-vingt-un',
      90: 'quatre-vingt-dix',
      91: 'quatre-vingt-onze',
      99: 'quatre-vingt-dix-neuf',
      100: 'cent',
      101: 'cent un',
      200: 'deux cents',
      201: 'deux cent un',
      280: 'deux cent quatre-vingts',
      1000: 'mille',
      1001: 'mille un',
      1999: 'mille neuf cent quatre-vingt-dix-neuf',
      2026: 'deux mille vingt-six',
      21000: 'vingt et un mille',
      80000: 'quatre-vingt mille',
      200000: 'deux cent mille',
      300500: 'trois cent mille cinq cents',
    };
    cases.forEach((n, words) {
      test('$n', () => expect(FrenchNumbers.toWords(n), words));
    });

    test('rejects what it cannot say', () {
      expect(() => FrenchNumbers.toWords(1000000), throwsRangeError);
    });
  });

  group('time', () {
    test('official 24-hour reading', () {
      expect(FrenchNumbers.timeOfficial(14, 30), 'quatorze heures trente');
      expect(FrenchNumbers.timeOfficial(1, 0), 'une heure');
      expect(FrenchNumbers.timeOfficial(21, 1), 'vingt et une heures une');
      expect(FrenchNumbers.timeOfficial(0, 15), 'zéro heure quinze');
    });

    test('everyday reading', () {
      expect(FrenchNumbers.timeEveryday(8, 15), 'huit heures et quart');
      expect(FrenchNumbers.timeEveryday(14, 30), 'deux heures et demie');
      expect(FrenchNumbers.timeEveryday(12, 30), 'midi et demi');
      expect(FrenchNumbers.timeEveryday(8, 45), 'neuf heures moins le quart');
      expect(FrenchNumbers.timeEveryday(11, 50), 'midi moins dix');
      expect(FrenchNumbers.timeEveryday(13, 5), 'une heure cinq');
      expect(FrenchNumbers.timeEveryday(0, 0), 'minuit');
    });
  });
}
