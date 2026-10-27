import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/path/data/journey_format.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/path/domain/lesson_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final stops = [
    for (final stage in Stage.values)
      ...JourneyFormat.parseStage(
          File('assets/data/journey/${stage.key}.json').readAsStringSync()),
  ];

  group('the content', () {
    test('every stage is built, with weeks of five lessons, review, checkpoint',
        () {
      for (final stage in Stage.values) {
        final mine = stops.where((s) => s.stage == stage).toList();
        expect(mine, isNotEmpty, reason: '${stage.name} has no lessons');
        final weeks = {for (final s in mine) s.week};
        expect(weeks.length, greaterThanOrEqualTo(2), reason: stage.name);
        for (final w in weeks) {
          final week = mine.where((s) => s.week == w).toList();
          expect(week.length, 7, reason: '${stage.name} week $w');
          expect(week.where((s) => s.kind == StopKind.lesson).length, 5);
          expect(week[5].kind, StopKind.review);
          expect(week[6].kind, StopKind.checkpoint);
        }
      }
      expect(stops.where((s) => s.kind == StopKind.lesson).length,
          greaterThanOrEqualTo(150));
    });

    test('ids are unique and the first week keeps its old ids', () {
      expect({for (final s in stops) s.id}.length, stops.length);
      expect(stops.first.id, 'depart-1');
      expect(stops.firstWhere((s) => s.stage == Stage.premiersPas).id,
          'premiers-1');
      expect(stops[6].id, 'depart-7');
      expect(stops[6].kind, StopKind.checkpoint);
    });

    test('every lesson teaches words and ends on a conversation', () {
      for (final stop in stops.where((s) => s.kind == StopKind.lesson)) {
        expect(stop.items, isNotEmpty, reason: stop.id);
        final steps = LessonBuilder.build(stop, stops, random: Random(1));
        expect(steps.first, isA<LearnStep>(), reason: stop.id);
        expect(steps.last, isA<DialogueStep>(), reason: stop.id);
      }
    });

    test('a lesson checks each pair, asks for French and has you speak',
        () {
      for (final stop in stops.where((s) => s.kind == StopKind.lesson)) {
        final steps = LessonBuilder.build(stop, stops, random: Random(3));
        expect(steps[0], isA<LearnStep>(), reason: stop.id);
        expect(steps[1], isA<LearnStep>(), reason: stop.id);
        expect(steps[2], anyOf(isA<ChoiceStep>(), isA<ListenStep>()),
            reason: stop.id);
        expect(steps.whereType<SpeakStep>(), isNotEmpty, reason: stop.id);
        expect(steps.whereType<ChoiceStep>().where((c) => c.french),
            isNotEmpty,
            reason: stop.id);
        for (final c in steps.whereType<ChoiceStep>()) {
          expect(c.options.toSet().length, c.options.length,
              reason: '${stop.id} ${c.prompt}');
        }
      }
    });

    test('a retry keeps the right answer under new positions', () {
      const step = ChoiceStep(
          prompt: 'p', options: ['a', 'b', 'c', 'd'], answer: 2, about: 'x');
      for (var seed = 0; seed < 10; seed++) {
        final again =
            LessonBuilder.again(step, random: Random(seed)) as ChoiceStep;
        expect(again.options[again.answer], 'c');
        expect(again.about, 'x');
      }
    });

    test('after shuffling, every answer still points at the right option',
        () {
      for (final stop in stops.where((s) => s.kind == StopKind.lesson)) {
        final authored = {
          for (final e in stop.exercises)
            if (e case ChoiceStep(:final prompt, :final options))
              prompt: options.first,
        };
        for (final step in LessonBuilder.build(stop, stops, random: Random(7))) {
          switch (step) {
            case ChoiceStep(:final prompt, :final options, :final answer):
              expect(answer, inInclusiveRange(0, options.length - 1));
              if (authored[prompt] case final right?) {
                expect(options[answer], right, reason: stop.id);
              }
            case DialogueStep(:final lines):
              for (final l in lines.where((l) => l.isLearner)) {
                expect(l.answer, inInclusiveRange(0, l.options.length - 1));
              }
            default:
          }
        }
      }
    });

    test('reviews and checkpoints quiz only what their week taught', () {
      for (final stop in stops.where((s) => s.kind != StopKind.lesson)) {
        final taught = {
          for (final s in stops)
            if (s.stage == stop.stage &&
                s.week == stop.week &&
                s.kind == StopKind.lesson)
              for (final i in s.items) ...[i.es, i.fr],
        };
        final steps = LessonBuilder.build(stop, stops, random: Random(2));
        expect(steps.length, greaterThanOrEqualTo(6), reason: stop.id);
        for (final step in steps) {
          if (step case ChoiceStep(:final options, :final answer, :final about)
              when about != null) {
            expect(taught, contains(options[answer]), reason: stop.id);
          }
        }
        if (stop.kind == StopKind.checkpoint) {
          expect(steps.last, isA<DialogueStep>(), reason: stop.id);
        }
      }
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
      await path.complete(stops.first, now: day);
      expect(path.newToday(now: day), 3, reason: 'a done stop does not count');
      expect(
          path.canStartNew(
              premium: false, now: day.add(const Duration(days: 1))),
          isTrue);
    });

    test('the placement stage skips everything before it', () async {
      await path.setStartStage(Stage.enVille);
      expect(path.next?.stage, Stage.enVille);
      expect(path.next?.id, 'ville-1');
      expect(path.progressIn(Stage.auCafe), 1);
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
