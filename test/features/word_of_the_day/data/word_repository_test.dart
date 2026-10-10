import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

void main() {
  // The repository reads a real bundled asset, so the asset bundle has to be
  // initialised before any of this runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordRepository repo;

  setUpAll(() async {
    repo = WordRepository();
    await repo.load();
  });

  group('corpus integrity', () {
    test('the bundled dataset loads', () {
      expect(repo.isLoaded, isTrue);
      expect(repo.all, isNotEmpty);
    });

    test('ids are unique', () {
      final ids = repo.all.map((w) => w.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('French headwords are unique', () {
      final words = repo.all.map((w) => w.french).toList();
      expect(words.toSet().length, words.length);
    });

    test('every category and level is represented', () {
      final categories = repo.all.map((w) => w.category).toSet();
      final levels = repo.all.map((w) => w.level).toSet();
      expect(categories.length, WordCategory.values.length);
      expect(levels.length, CefrLevel.values.length);
    });

    test('no entry is missing its translation or example', () {
      for (final word in repo.all) {
        expect(word.translationEs, isNotEmpty, reason: word.id);
        expect(word.exampleFr, isNotEmpty, reason: word.id);
        expect(word.exampleEs, isNotEmpty, reason: word.id);
        expect(word.ipa, isNotEmpty, reason: word.id);
      }
    });
  });

  group('wordOfTheDay', () {
    test('is stable for the same calendar day', () {
      final date = DateTime(2026, 10, 10);
      final first = repo.wordOfTheDay(date);
      final second = repo.wordOfTheDay(DateTime(2026, 10, 10, 23, 59));

      expect(first, isNotNull);
      expect(second!.id, first!.id);
    });

    test('changes from one day to the next', () {
      final today = repo.wordOfTheDay(DateTime(2026, 10, 10));
      final tomorrow = repo.wordOfTheDay(DateTime(2026, 10, 11));
      expect(tomorrow!.id, isNot(today!.id));
    });

    test('any window of pool-length days covers the pool exactly once', () {
      final levels = {CefrLevel.a1};
      final poolSize = repo.byLevel(CefrLevel.a1).length;

      // Every starting offset, not just the aligned ones: the rotation makes
      // the no-repeat guarantee hold for arbitrary windows.
      for (var offset = 0; offset < poolSize + 3; offset++) {
        final start = DateTime(2026, 3, 1).add(Duration(days: offset));
        final seen = <String>{};
        for (var i = 0; i < poolSize; i++) {
          seen.add(repo
              .wordOfTheDay(start.add(Duration(days: i)), levels: levels)!
              .id);
        }
        expect(seen.length, poolSize, reason: 'offset $offset');
      }
    });

    test('the full corpus also rotates without repeats', () {
      final poolSize = repo.all.length;
      final start = DateTime(2026, 7, 13);
      final seen = <String>{};
      for (var i = 0; i < poolSize; i++) {
        seen.add(repo.wordOfTheDay(start.add(Duration(days: i)))!.id);
      }
      expect(seen.length, poolSize);
    });

    test('respects the level filter', () {
      for (var i = 0; i < 30; i++) {
        final word = repo.wordOfTheDay(
          DateTime(2026, 1, 1).add(Duration(days: i)),
          levels: {CefrLevel.c1, CefrLevel.c2},
        );
        expect([CefrLevel.c1, CefrLevel.c2], contains(word!.level));
      }
    });

    test('returns null when the filter matches nothing', () {
      expect(repo.wordOfTheDay(DateTime.now(), levels: const {}), isNotNull);
    });
  });

  group('search', () {
    test('matches the French headword', () {
      final results = repo.search('bonjour');
      expect(results.map((w) => w.french), contains('bonjour'));
    });

    test('matches the Spanish translation', () {
      final results = repo.search('gracias');
      expect(results.map((w) => w.french), contains('merci'));
    });

    test('ignores accents in the query', () {
      final withAccent = repo.search('café');
      final without = repo.search('cafe');
      expect(without.map((w) => w.id), withAccent.map((w) => w.id));
      expect(without, isNotEmpty);
    });

    test('an empty query returns the whole corpus', () {
      expect(repo.search('   ').length, repo.all.length);
    });
  });

  group('distractorsFor', () {
    test('never includes the target and never duplicates a meaning', () {
      for (final target in repo.all.take(25)) {
        final distractors = repo.distractorsFor(target, count: 3);

        expect(distractors.length, 3, reason: target.id);
        expect(distractors.map((w) => w.id), isNot(contains(target.id)));
        expect(
          distractors.map((w) => w.translationEs).toSet().length,
          distractors.length,
          reason: 'duplicate meanings for ${target.id}',
        );
        expect(distractors.map((w) => w.translationEs),
            isNot(contains(target.translationEs)));
      }
    });

    test('is deterministic for the same seed', () {
      final target = repo.all.first;
      final a = repo.distractorsFor(target, seed: 42).map((w) => w.id);
      final b = repo.distractorsFor(target, seed: 42).map((w) => w.id);
      expect(a, b);
    });

    test('prefers same-category distractors when they exist', () {
      final target =
          repo.all.firstWhere((w) => repo.countForCategory(w.category) > 4);
      final distractors = repo.distractorsFor(target, count: 3);
      final sameCategory =
          distractors.where((w) => w.category == target.category).length;
      expect(sameCategory, greaterThanOrEqualTo(2));
    });
  });

  group('pool', () {
    test('filters by level and category together', () {
      final result = repo.pool(
        levels: {CefrLevel.a1},
        category: WordCategory.food,
      );
      expect(result, isNotEmpty);
      for (final word in result) {
        expect(word.level, CefrLevel.a1);
        expect(word.category, WordCategory.food);
      }
    });
  });
}
