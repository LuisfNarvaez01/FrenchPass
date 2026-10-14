import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressRepository repo;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    repo = ProgressRepository(storage);
  });

  String key(DateTime date) => ProgressRepository.dayKey(date);

  /// Moves every card's last review to two days ago, so the next attempt
  /// counts as a new spaced review rather than same-day practice.
  Future<void> nextDay() async {
    final cards = storage.getJsonMap(StorageKeys.srsCards);
    final past = DateTime.now().subtract(const Duration(days: 2));
    for (final card in cards.values) {
      (card as Map<String, dynamic>)['lastReviewDate'] = past.toIso8601String();
    }
    await storage.setJsonMap(StorageKeys.srsCards, cards);
  }

  group('favourites', () {
    test('toggle adds then removes', () async {
      expect(repo.isFavorite('a1-001'), isFalse);

      expect(await repo.toggleFavorite('a1-001'), isTrue);
      expect(repo.isFavorite('a1-001'), isTrue);

      expect(await repo.toggleFavorite('a1-001'), isFalse);
      expect(repo.isFavorite('a1-001'), isFalse);
    });
  });

  group('recordAttempt', () {
    test('persists the attempt, the card and today as studied', () async {
      final card = await repo.recordAttempt(
        wordId: 'a1-001',
        score: 0.9,
        kind: AttemptKind.pronunciation,
      );

      expect(card.wordId, 'a1-001');
      expect(card.repetitions, 1);
      expect(repo.loadAttempts().length, 1);
      expect(repo.studiedToday, isTrue);
      expect(repo.cardFor('a1-001'), isNotNull);
    });

    test('advances the SM-2 schedule across successes on separate days',
        () async {
      await repo.recordAttempt(
          wordId: 'w', score: 1.0, kind: AttemptKind.quiz);
      await nextDay();
      await repo.recordAttempt(
          wordId: 'w', score: 1.0, kind: AttemptKind.quiz);
      await nextDay();
      final third = await repo.recordAttempt(
          wordId: 'w', score: 1.0, kind: AttemptKind.quiz);

      expect(third.repetitions, 3);
      // 1 day → 6 days → 6 × easiness.
      expect(third.intervalDays, greaterThan(6));
    });

    test('a failure resets the interval', () async {
      await repo.recordAttempt(
          wordId: 'w', score: 1.0, kind: AttemptKind.quiz);
      await repo.recordAttempt(
          wordId: 'w', score: 1.0, kind: AttemptKind.quiz);
      final failed = await repo.recordAttempt(
          wordId: 'w', score: 0.1, kind: AttemptKind.quiz);

      expect(failed.repetitions, 0);
      expect(failed.intervalDays, 1);
    });
  });

  group('streak', () {
    test('is zero with no study days', () {
      expect(repo.currentStreak(), 0);
    });

    test('counts consecutive days ending today', () async {
      final today = DateTime.now();
      await storage.setStringSet(StorageKeys.studiedDays, {
        key(today),
        key(today.subtract(const Duration(days: 1))),
        key(today.subtract(const Duration(days: 2))),
      });

      expect(repo.currentStreak(), 3);
    });

    test('survives a day that is not finished yet', () async {
      // Studied yesterday but not yet today: the streak is still alive.
      final today = DateTime.now();
      await storage.setStringSet(StorageKeys.studiedDays, {
        key(today.subtract(const Duration(days: 1))),
        key(today.subtract(const Duration(days: 2))),
      });

      expect(repo.currentStreak(), 2);
    });

    test('breaks when the gap is two days', () async {
      final today = DateTime.now();
      await storage.setStringSet(StorageKeys.studiedDays, {
        key(today.subtract(const Duration(days: 2))),
        key(today.subtract(const Duration(days: 3))),
      });

      expect(repo.currentStreak(), 0);
    });

    test('a run across a daylight-saving change stays unbroken', () async {
      // Europe moved its clocks on 29 March 2026: that day had 23 hours.
      await storage.setStringSet(StorageKeys.studiedDays,
          {'2026-03-28', '2026-03-29', '2026-03-30'});
      expect(repo.longestStreak(), 3);
      expect(repo.currentStreak(now: DateTime(2026, 3, 30, 0, 30)), 3);
    });

    test('longestStreak finds the best historical run', () async {
      final base = DateTime(2026, 5, 1);
      await storage.setStringSet(StorageKeys.studiedDays, {
        key(base),
        key(base.add(const Duration(days: 1))),
        key(base.add(const Duration(days: 2))),
        key(base.add(const Duration(days: 3))),
        // gap
        key(base.add(const Duration(days: 8))),
      });

      expect(repo.longestStreak(), 4);
    });
  });

  group('stats and aggregates', () {
    test('averages the recorded scores', () async {
      await repo.recordAttempt(
          wordId: 'a', score: 1.0, kind: AttemptKind.quiz);
      await repo.recordAttempt(
          wordId: 'b', score: 0.5, kind: AttemptKind.quiz);

      final stats = repo.stats();
      expect(stats.totalAttempts, 2);
      expect(stats.averageScore, closeTo(0.75, 0.001));
      expect(stats.wordsSeen, 2);
    });

    test('counts a word as mastered after three successful repetitions',
        () async {
      for (var i = 0; i < 3; i++) {
        await repo.recordAttempt(
            wordId: 'a', score: 1.0, kind: AttemptKind.quiz);
        await nextDay();
      }
      expect(repo.stats().mastered, 1);
    });

    test('three tries on the same day do not master a word', () async {
      for (var i = 0; i < 3; i++) {
        await repo.recordAttempt(
            wordId: 'a', score: 1.0, kind: AttemptKind.quiz);
      }
      expect(repo.stats().mastered, 0);
    });

    test('dailyCounts returns one bucket per requested day', () async {
      await repo.recordAttempt(
          wordId: 'a', score: 1.0, kind: AttemptKind.quiz);

      final counts = repo.dailyCounts(days: 7);
      expect(counts.length, 7);
      expect(counts.last.count, 1);
      expect(counts.first.count, 0);
    });

    test('dailyScores skips days with no practice', () async {
      await repo.recordAttempt(
          wordId: 'a', score: 0.8, kind: AttemptKind.quiz);

      final scores = repo.dailyScores(days: 14);
      expect(scores.length, 1);
      expect(scores.single.score, closeTo(0.8, 0.001));
    });

    test('averageByWord means each word separately', () async {
      await repo.recordAttempt(
          wordId: 'a', score: 1.0, kind: AttemptKind.quiz);
      await repo.recordAttempt(
          wordId: 'a', score: 0.0, kind: AttemptKind.quiz);
      await repo.recordAttempt(
          wordId: 'b', score: 0.6, kind: AttemptKind.quiz);

      final averages = repo.averageByWord();
      expect(averages['a'], closeTo(0.5, 0.001));
      expect(averages['b'], closeTo(0.6, 0.001));
    });
  });

  group('dueCards', () {
    test('a freshly reviewed card is not due today', () async {
      await repo.recordAttempt(
          wordId: 'a', score: 1.0, kind: AttemptKind.quiz);
      expect(repo.dueCards(), isEmpty);
    });
  });

  group('resetAll', () {
    test('clears progress and settings keys', () async {
      await repo.recordAttempt(
          wordId: 'a', score: 1.0, kind: AttemptKind.quiz);
      await repo.toggleFavorite('a');

      await repo.resetAll();

      expect(repo.loadAttempts(), isEmpty);
      expect(repo.loadFavorites(), isEmpty);
      expect(repo.loadCards(), isEmpty);
      expect(repo.currentStreak(), 0);
    });
  });

  group('corrupt storage', () {
    test('a malformed JSON document is dropped rather than crashing',
        () async {
      await storage.setString(StorageKeys.attempts, 'not json at all');
      expect(repo.loadAttempts(), isEmpty);
    });

    test('a malformed card entry is skipped', () async {
      await storage.setJsonMap(StorageKeys.srsCards, {
        'good': {
          'wordId': 'good',
          'repetitions': 2,
          'easinessFactor': 2.5,
          'intervalDays': 6,
          'nextReviewDate': DateTime(2026, 1, 1).toIso8601String(),
        },
        'bad': {'nope': true},
      });

      final cards = repo.loadCards();
      expect(cards.keys, ['good']);
    });
  });
}
