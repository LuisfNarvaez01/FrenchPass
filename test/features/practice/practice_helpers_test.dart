import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/reminder_service.dart';
import 'package:french_pass/core/text/answer_check.dart';
import 'package:french_pass/features/practice/presentation/pages/numbers_page.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('word lookup for readings', () {
    late WordRepository words;
    setUpAll(() async {
      words = WordRepository();
      await words.load();
    });

    test('strips punctuation and case', () {
      expect(words.lookup('Bonjour,')?.french, 'bonjour');
    });

    test('sees through elision', () {
      expect(words.lookup("l'école")?.french, 'école');
      expect(words.lookup('l’hôtel')?.french, 'hôtel');
    });

    test('finds the base of a plural', () {
      expect(words.lookup('fleurs')?.french, 'fleur');
    });

    test('returns null for what is not in the catalog', () {
      expect(words.lookup('xyzzy'), isNull);
      expect(words.lookup('…'), isNull);
    });
  });

  group('number answers', () {
    test('digits, with or without spaces', () {
      expect(compareNumberAnswer('71', '71'), AnswerMatch.exact);
      expect(compareNumberAnswer('1 999', '1999'), AnswerMatch.exact);
      expect(compareNumberAnswer('17', '71'), AnswerMatch.wrong);
    });

    test('times in the usual spellings', () {
      for (final typed in ['14:30', '14h30', '14 30', '14.30', '14H30']) {
        expect(compareNumberAnswer(typed, '14:30'), AnswerMatch.exact,
            reason: typed);
      }
      expect(compareNumberAnswer('8h', '8:00'), AnswerMatch.exact);
      expect(compareNumberAnswer('2:30', '14:30'), AnswerMatch.wrong);
    });
  });

  group('reminder', () {
    test('fires today if the hour is still ahead, else tomorrow', () {
      final morning = DateTime(2026, 10, 14, 7);
      expect(ReminderService.nextFiring(9, morning), DateTime(2026, 10, 14, 9));
      final evening = DateTime(2026, 10, 14, 21);
      expect(ReminderService.nextFiring(9, evening), DateTime(2026, 10, 15, 9));
    });

    test('reviews come first, then a streak at risk', () {
      expect(
          ReminderService.messageFor(due: 12, streak: 5, studiedToday: false)
              .title,
          'Tienes 12 palabras para repasar');
      expect(
          ReminderService.messageFor(due: 0, streak: 5, studiedToday: false)
              .title,
          'Llevas 5 días seguidos');
      expect(
          ReminderService.messageFor(due: 0, streak: 5, studiedToday: true)
              .title,
          'Tu palabra del día te espera');
    });
  });
}
