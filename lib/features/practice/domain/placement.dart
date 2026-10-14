import 'dart:math';

import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

class PlacementQuestion {
  final ChoiceItem item;
  final CefrLevel level;
  const PlacementQuestion(this.item, this.level);
}

/// A short test that places a new learner at A1, A2, B1 or B2.
abstract final class Placement {
  static const levels = [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2
  ];
  static const wordsPerLevel = 3;

  /// A level counts as known from this share of right answers.
  static const passMark = 0.6;

  /// Three words per level, plus one grammar question for A1 to B1,
  /// easiest first so a beginner isn't greeted by B2.
  static List<PlacementQuestion> build(
    WordRepository words,
    LearningContent content, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final out = <PlacementQuestion>[];
    for (final level in levels) {
      final pool = words
          .byLevel(level)
          .where((w) =>
              w.wordType != WordType.expression &&
              w.wordType != WordType.phrase)
          .toList()
        ..shuffle(rng);
      for (final word in pool.take(wordsPerLevel)) {
        final wrong = words
            .distractorsFor(word, count: 3, seed: rng.nextInt(1 << 30))
            .map((w) => w.translationEs)
            .toList();
        final options = {word.translationEs, ...wrong}.toList()..shuffle(rng);
        out.add(PlacementQuestion(
          ChoiceItem(
            prompt: '¿Qué significa «${word.french}»?',
            options: options,
            answer: options.indexOf(word.translationEs),
          ),
          level,
        ));
      }
      final topics = content.grammar.where((t) => t.level == level).toList();
      if (topics.isNotEmpty) {
        final topic = topics[rng.nextInt(topics.length)];
        final exercise = topic.exercises[rng.nextInt(topic.exercises.length)];
        out.add(PlacementQuestion(exercise, level));
      }
    }
    return out;
  }

  /// The highest level passed without skipping one below it.
  static CefrLevel score(List<(CefrLevel, bool)> answers) {
    var reached = CefrLevel.a1;
    for (final level in levels) {
      final mine = answers.where((a) => a.$1 == level).toList();
      if (mine.isEmpty) break;
      final right = mine.where((a) => a.$2).length;
      if (right / mine.length < passMark) break;
      reached = level;
    }
    return reached;
  }

  static LevelFilter filterFor(CefrLevel level) => switch (level) {
        CefrLevel.a1 || CefrLevel.a2 => LevelFilter.beginner,
        CefrLevel.b1 || CefrLevel.b2 => LevelFilter.intermediate,
        CefrLevel.c1 || CefrLevel.c2 => LevelFilter.advanced,
      };
}
