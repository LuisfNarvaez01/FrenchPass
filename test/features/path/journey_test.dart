import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/path/domain/lesson_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final stops =
      PathRepository.parse(File('assets/data/journey.json').readAsStringSync());

  group('the content', () {
    test('each built week has five lessons, a review and a checkpoint', () {
      for (final stage in {for (final s in stops) s.stage}) {
        final week = stops.where((s) => s.stage == stage && s.week == 1);
        expect(week.length, 7, reason: stage.name);
        expect(week.where((s) => s.kind == StopKind.lesson).length, 5);
        expect(week.last.kind, StopKind.checkpoint);
      }
    });

    test('every lesson teaches words and ends on a conversation', () {
      for (final stop in stops.where((s) => s.kind == StopKind.lesson)) {
        expect(stop.items, isNotEmpty, reason: stop.id);
        final steps = LessonBuilder.build(stop, stops, random: Random(1));
        expect(steps.first, isA<LearnStep>(), reason: stop.id);
        expect(steps.last, isA<DialogueStep>(), reason: stop.id);
      }
    });

    test('answers point at a real option and options do not repeat', () {
      for (final stop in stops) {
        for (final step in stop.exercises) {
          switch (step) {
            case ChoiceStep(:final options, :final answer):
            case ListenStep(:final options, :final answer):
              expect(answer, inInclusiveRange(0, options.length - 1),
                  reason: stop.id);
              expect(options.toSet().length, options.length, reason: stop.id);
            case DialogueStep(:final lines):
              for (final l in lines.where((l) => l.isLearner)) {
                expect(l.answer, inInclusiveRange(0, l.options.length - 1),
                    reason: stop.id);
              }
            default:
          }
        }
      }
    });

    test('a review and a checkpoint quiz only what the week taught', () {
      final review = stops.firstWhere((s) => s.kind == StopKind.review);
      final taught = {
        for (final s in stops)
          if (s.stage == review.stage && s.kind == StopKind.lesson)
            for (final i in s.items) i.es,
      };
      final steps = LessonBuilder.build(review, stops, random: Random(2));
      expect(steps.length, greaterThanOrEqualTo(6));
      for (final step in steps) {
        if (step case ChoiceStep(:final options, :final answer)) {
          expect(taught, contains(options[answer]));
        }
      }
      final checkpoint = stops.firstWhere((s) => s.kind == StopKind.checkpoint);
      final cpSteps = LessonBuilder.build(checkpoint, stops, random: Random(2));
      expect(cpSteps.last, isA<DialogueStep>());
    });
  });

  group('progress', () {
    late PathRepository path;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      path = PathRepository(await StorageService.create())
        ..stopsForTesting = stops;
    });

    test('the journey starts at the first stop, in order', () async {
      expect(path.next?.id, 'depart-1');
      expect(path.isOpen(stops[1]), isFalse);
      await path.complete(stops[0]);
      expect(path.next?.id, 'depart-2');
      expect(path.isOpen(stops[0]), isTrue, reason: 'done stops reopen');
    });

    test('free learners open three new stops a day; Premium has no cap',
        () async {
      final day = DateTime(2026, 10, 16, 9);
      for (final stop in stops.take(3)) {
        expect(path.canStartNew(premium: false, now: day), isTrue);
        await path.complete(stop, now: day);
      }
      expect(path.newToday(now: day), 3);
      expect(path.canStartNew(premium: false, now: day), isFalse);
      expect(path.canStartNew(premium: true, now: day), isTrue);
      // Going over a stop already done doesn't count.
      await path.complete(stops.first, now: day);
      expect(path.newToday(now: day), 3);
      // A new day, a new allowance.
      expect(
          path.canStartNew(
              premium: false, now: day.add(const Duration(days: 1))),
          isTrue);
    });

    test('a placement past the built stages skips them', () async {
      await path.setStartStage(Stage.premiersPas);
      expect(path.next?.stage, Stage.premiersPas);
      expect(path.progressIn(Stage.depart), 1);
      await path.setStartStage(Stage.enVille);
      expect(path.next, isNull, reason: 'that stage is not built yet');
      expect(path.currentStage, Stage.enVille);
    });

    test('mistakes are kept once, latest last, and cleared when learnt',
        () async {
      await path.addMistake('bonjour');
      await path.addMistake('merci');
      await path.addMistake('bonjour');
      expect(path.mistakes, ['merci', 'bonjour']);
      expect(path.itemFor('merci')?.es, 'gracias');
      await path.clearMistake('merci');
      expect(path.mistakes, ['bonjour']);
    });
  });
}
