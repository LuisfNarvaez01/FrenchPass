import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/achievements.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  late ProgressRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    repo = ProgressRepository(storage);
  });

  group('daily goal', () {
    test('counts exercises per day against the goal', () async {
      final day = DateTime(2026, 10, 14, 9);
      await repo.setDailyGoal(10);
      await repo.recordPractice(PracticeKind.quiz, count: 6, now: day);
      expect(repo.practiceToday(now: day), 6);
      expect(repo.goalMetToday(now: day), isFalse);
      await repo.recordPractice(PracticeKind.dictation, count: 4, now: day);
      expect(repo.goalMetToday(now: day), isTrue);
      expect(repo.practiceToday(now: day.add(const Duration(days: 1))), 0);
      expect(repo.practiceTotals()[PracticeKind.quiz], 6);
      expect(repo.goalDaysMet(), 1);
    });

    test('practising marks the day as studied', () async {
      final day = DateTime(2026, 10, 14, 9);
      await repo.recordPractice(PracticeKind.grammar, now: day);
      expect(repo.loadStudiedDays(), contains('2026-10-14'));
    });
  });

  group('streak freezes', () {
    Future<void> studyDays(DateTime from, int days) async {
      for (var i = 0; i < days; i++) {
        await repo.markStudiedToday(
            now: DateTime(from.year, from.month, from.day + i, 10));
      }
    }

    test('seven days in a row earn one, capped at two', () async {
      await studyDays(DateTime(2026, 9, 1), 7);
      expect(repo.streakFreezes, 1);
      // Studying the 7th day twice doesn't pay twice.
      await repo.markStudiedToday(now: DateTime(2026, 9, 7, 20));
      expect(repo.streakFreezes, 1);
      await studyDays(DateTime(2026, 9, 8), 14);
      expect(repo.streakFreezes, ProgressRepository.maxFreezes);
    });

    test('a single missed day is covered and the streak survives', () async {
      await studyDays(DateTime(2026, 9, 1), 7); // 1-7 Sept, earns one.
      final ninth = DateTime(2026, 9, 9, 8); // 8 Sept missed.
      expect(await repo.protectStreak(now: ninth), isTrue);
      expect(repo.streakFreezes, 0);
      expect(repo.frozenDays, {'2026-09-08'});
      expect(repo.currentStreak(now: ninth), 8);
    });

    test('two missed days are not covered', () async {
      await studyDays(DateTime(2026, 9, 1), 7);
      expect(await repo.protectStreak(now: DateTime(2026, 9, 10, 8)), isFalse);
      expect(repo.streakFreezes, 1);
    });
  });

  group('achievements', () {
    test('unlock once and are celebrated once', () async {
      final service = AchievementService(storage, repo, tutorLessons: () => 0);
      expect(await service.refresh(), isEmpty);

      await repo.recordPractice(PracticeKind.quiz);
      final fresh = await service.refresh();
      expect(fresh.map((a) => a.id), contains('first-step'));
      expect(await service.refresh(), isEmpty, reason: 'already unlocked');

      expect(service.unseen().map((a) => a.id), contains('first-step'));
      await service.markAllSeen();
      expect(service.unseen(), isEmpty);
    });

    test('ids are unique', () {
      final ids = Achievements.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
