import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/practice/domain/placement.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('score', () {
    List<(CefrLevel, bool)> answers(Map<CefrLevel, List<bool>> byLevel) => [
          for (final e in byLevel.entries)
            for (final right in e.value) (e.key, right),
        ];

    test('the highest level passed in a row', () {
      expect(
        Placement.score(answers({
          CefrLevel.a1: [true, true, true, true],
          CefrLevel.a2: [true, true, false, true],
          CefrLevel.b1: [false, true, false, false],
          CefrLevel.b2: [true, true, true],
        })),
        CefrLevel.a2,
        reason: 'B2 by luck does not count after failing B1',
      );
    });

    test('failing A1 still places at A1', () {
      expect(
          Placement.score(answers({
            CefrLevel.a1: [false, false, true],
          })),
          CefrLevel.a1);
    });

    test('maps to the app level filter', () {
      expect(Placement.filterFor(CefrLevel.a2), LevelFilter.beginner);
      expect(Placement.filterFor(CefrLevel.b2), LevelFilter.intermediate);
    });
  });

  test('builds a test from the bundled content', () async {
    final words = WordRepository();
    await words.load();
    final content = LearningContent();
    await content.load();

    final questions = Placement.build(words, content, random: Random(1));
    expect(questions.length, 4 * Placement.wordsPerLevel + 3);
    expect(questions.first.level, CefrLevel.a1);
    for (final q in questions) {
      expect(q.item.answer, inInclusiveRange(0, q.item.options.length - 1));
      expect(q.item.options.length, greaterThanOrEqualTo(2));
    }
  });
}
