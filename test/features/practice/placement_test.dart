import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/practice/domain/placement.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

void main() {
  final bank =
      Placement.parse(File('assets/data/placement.json').readAsStringSync());

  group('the bank', () {
    test('every level has a full, mixed block of valid questions', () {
      for (final level in Placement.levels) {
        final mine = bank.where((q) => q.level == level).toList();
        expect(mine.length, greaterThanOrEqualTo(Placement.perLevel),
            reason: level.name);
        expect(mine.any((q) => q.kind == PlacementKind.listening), isTrue,
            reason: '${level.name} needs a listening question');
        expect(mine.any((q) => q.kind == PlacementKind.reading), isTrue,
            reason: '${level.name} needs a reading question');
        for (final q in mine) {
          expect(q.item.options.length, 4, reason: q.item.prompt);
          expect(q.item.options.toSet().length, 4,
              reason: 'repeated option in ${q.item.prompt}');
          if (q.kind == PlacementKind.listening) expect(q.listen, isNotNull);
          if (q.kind == PlacementKind.reading) expect(q.passage, isNotNull);
        }
      }
    });

    test('a block has five questions with listening and reading, shuffled',
        () {
      final placement = Placement(bank, random: Random(3));
      final block = placement.blockFor(CefrLevel.b1);
      expect(block.length, Placement.perLevel);
      expect(block.any((q) => q.kind == PlacementKind.listening), isTrue);
      expect(block.any((q) => q.kind == PlacementKind.reading), isTrue);
      // The bank lists every right answer first; shuffling must move some.
      expect(block.any((q) => q.item.answer != 0), isTrue);
    });
  });

  group('score', () {
    test('climbs only while four of five are right', () {
      final result = Placement.score({
        CefrLevel.a1: [true, true, true, true, false],
        CefrLevel.a2: [true, true, true, false, true],
        CefrLevel.b1: [true, false, true, false, true],
      });
      expect(result.level, CefrLevel.a2);
      expect(result.stage, Stage.enVille);
      expect(result.right, 11);
      expect(result.total, 15);
    });

    test('three of five is not enough, even at A1', () {
      final result = Placement.score({
        CefrLevel.a1: [true, true, true, false, false],
      });
      expect(result.level, isNull);
      expect(result.levelLabel, 'Pre-A1');
      expect(result.stage, Stage.premiersPas,
          reason: 'some French, not enough for A1');
    });

    test('knowing nothing starts the journey at zero', () {
      final result = Placement.score({
        CefrLevel.a1: [false, true, false, false, false],
      });
      expect(result.stage, Stage.depart);
    });

    test('passing everything lands at the top', () {
      final all = {
        for (final level in Placement.levels)
          level: [true, true, true, true, true],
      };
      final result = Placement.score(all);
      expect(result.level, CefrLevel.c1);
      expect(result.stage, Stage.parisien);
    });

    test('maps to the app level filter', () {
      expect(Placement.filterFor(null), LevelFilter.beginner);
      expect(Placement.filterFor(CefrLevel.a2), LevelFilter.beginner);
      expect(Placement.filterFor(CefrLevel.b2), LevelFilter.intermediate);
    });
  });
}
