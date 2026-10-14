import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  var premium = false;
  var now = DateTime(2026, 10, 14, 9);

  UsageService usage() =>
      UsageService(storage, isPremium: () => premium, clock: () => now);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    premium = false;
    now = DateTime(2026, 10, 14, 9);
  });

  group('free plan', () {
    test('starts with the 10-minute trial', () {
      expect(usage().tutorTimeLeft(), UsageLimits.freeTutor);
      expect(usage().canStartTutor, isTrue);
      expect(usage().freeTutorUsedUp, isFalse);
    });

    test('the trial runs out and never comes back', () async {
      await usage().addTutorTime(const Duration(minutes: 7));
      expect(usage().tutorTimeLeft(), const Duration(minutes: 3));
      await usage().addTutorTime(const Duration(minutes: 4));
      expect(usage().tutorTimeLeft(), Duration.zero);
      expect(usage().canStartTutor, isFalse);

      now = DateTime(2026, 12, 1);
      expect(usage().tutorTimeLeft(), Duration.zero, reason: 'not monthly');
    });

    test('allows five AI requests a day', () async {
      for (var i = 0; i < 5; i++) {
        expect(usage().canUseAi, isTrue);
        await usage().addAiQuery();
      }
      expect(usage().canUseAi, isFalse);

      now = now.add(const Duration(days: 1));
      expect(usage().aiQueriesLeft(), UsageLimits.freeAiPerDay);
    });
  });

  group('premium', () {
    test('gets the full month even after using the trial', () async {
      await usage().addTutorTime(UsageLimits.freeTutor);
      premium = true;
      expect(usage().tutorTimeLeft(), UsageLimits.premiumTutorPerMonth);
    });

    test('minutes reset with the calendar month', () async {
      premium = true;
      await usage().addTutorTime(const Duration(minutes: 150));
      expect(usage().canStartTutor, isFalse);

      now = DateTime(2026, 11, 1, 8);
      expect(usage().tutorTimeLeft(), UsageLimits.premiumTutorPerMonth);
    });

    test('a lapsed subscriber is back on whatever trial was left', () async {
      premium = true;
      await usage().addTutorTime(const Duration(minutes: 30));
      premium = false;
      expect(usage().tutorTimeLeft(), UsageLimits.freeTutor);
    });
  });

  test('wiping the learner data keeps the meter', () async {
    await usage().addTutorTime(UsageLimits.freeTutor);
    await storage.clearAll();
    expect(usage().canStartTutor, isFalse);
  });
}
