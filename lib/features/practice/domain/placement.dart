import 'dart:convert';
import 'dart:math';

import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

enum PlacementKind { grammar, vocab, reading, listening }

class PlacementQuestion {
  final ChoiceItem item;
  final CefrLevel level;
  final PlacementKind kind;

  /// A text to read before answering.
  final String? passage;

  /// French to listen to before answering.
  final String? listen;

  const PlacementQuestion(
    this.item,
    this.level, {
    this.kind = PlacementKind.grammar,
    this.passage,
    this.listen,
  });

  factory PlacementQuestion.fromJson(Map<String, dynamic> j) =>
      PlacementQuestion(
        ChoiceItem(
          prompt: j['prompt'] as String,
          options: (j['options'] as List).cast<String>(),
          answer: j['answer'] as int,
          why: j['why'] as String? ?? '',
        ),
        CefrLevel.values.byName(j['level'] as String),
        kind: PlacementKind.values.byName(j['kind'] as String),
        passage: j['passage'] as String?,
        listen: j['listen'] as String?,
      );

  /// The same question with its options in a new order.
  PlacementQuestion shuffled(Random rng) {
    final right = item.options[item.answer];
    final options = [...item.options]..shuffle(rng);
    return PlacementQuestion(
      ChoiceItem(
        prompt: item.prompt,
        options: options,
        answer: options.indexOf(right),
        why: item.why,
      ),
      level,
      kind: kind,
      passage: passage,
      listen: listen,
    );
  }
}

/// What the test concluded.
class PlacementResult {
  /// The highest CEFR level passed, or null below A1.
  final CefrLevel? level;

  /// Where the journey starts.
  final Stage stage;

  final int right;
  final int total;

  const PlacementResult({
    required this.level,
    required this.stage,
    required this.right,
    required this.total,
  });

  String get levelLabel => level?.label ?? 'Pre-A1';
}

/// An adaptive placement test, A1 to C1.
///
/// It climbs a level at a time: five questions per level (mixing grammar,
/// vocabulary, reading and listening), and a level counts as passed only
/// with four right out of five. The first level failed ends the test, so a
/// beginner answers five questions and an advanced learner twenty-five.
class Placement {
  static const levels = [
    CefrLevel.a1,
    CefrLevel.a2,
    CefrLevel.b1,
    CefrLevel.b2,
    CefrLevel.c1,
  ];
  static const perLevel = 5;
  static const passRight = 4;

  final List<PlacementQuestion> bank;
  final Random _rng;
  Placement(this.bank, {Random? random}) : _rng = random ?? Random();

  static List<PlacementQuestion> parse(String raw) => [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          PlacementQuestion.fromJson(j),
      ];

  /// Five questions for [level], with a listening and a reading question
  /// whenever the bank has them, shuffled.
  List<PlacementQuestion> blockFor(CefrLevel level) {
    final pool = bank.where((q) => q.level == level).toList()..shuffle(_rng);
    final picked = <PlacementQuestion>[];
    for (final kind in [PlacementKind.listening, PlacementKind.reading]) {
      final q = pool.where((q) => q.kind == kind).firstOrNull;
      if (q != null) picked.add(q);
    }
    for (final q in pool) {
      if (picked.length >= perLevel) break;
      if (!picked.contains(q)) picked.add(q);
    }
    picked.shuffle(_rng);
    return [for (final q in picked) q.shuffled(_rng)];
  }

  /// The level after [level], or null at the top.
  static CefrLevel? after(CefrLevel level) {
    final i = levels.indexOf(level);
    return i + 1 < levels.length ? levels[i + 1] : null;
  }

  static bool passed(List<bool> block) =>
      block.where((r) => r).length >= passRight;

  /// The result from each level's answers, in the order they were taken.
  static PlacementResult score(Map<CefrLevel, List<bool>> answers) {
    CefrLevel? reached;
    for (final level in levels) {
      final block = answers[level];
      if (block == null || !passed(block)) break;
      reached = level;
    }
    final a1Right = answers[CefrLevel.a1]?.where((r) => r).length ?? 0;
    final stage = switch (reached) {
      null => a1Right >= 2 ? Stage.premiersPas : Stage.depart,
      CefrLevel.a1 => Stage.auCafe,
      CefrLevel.a2 => Stage.enVille,
      CefrLevel.b1 => Stage.conversations,
      CefrLevel.b2 => Stage.debats,
      _ => Stage.parisien,
    };
    final all = [for (final b in answers.values) ...b];
    return PlacementResult(
      level: reached,
      stage: stage,
      right: all.where((r) => r).length,
      total: all.length,
    );
  }

  static LevelFilter filterFor(CefrLevel? level) => switch (level) {
        null || CefrLevel.a1 || CefrLevel.a2 => LevelFilter.beginner,
        CefrLevel.b1 || CefrLevel.b2 => LevelFilter.intermediate,
        CefrLevel.c1 || CefrLevel.c2 => LevelFilter.advanced,
      };
}
