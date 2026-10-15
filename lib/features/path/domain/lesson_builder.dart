import 'dart:math';

import 'package:french_pass/features/path/domain/journey.dart';

/// Turns a stop into the screens the learner goes through.
///
/// A lesson teaches its words one by one, then practises them (the authored
/// exercises, a matching round) and ends on the micro-conversation, the
/// small win. A review and a checkpoint are built from the week's earlier
/// lessons, so they always cover exactly what was taught.
abstract final class LessonBuilder {
  static List<LessonStep> build(
    PathStop stop,
    List<PathStop> journey, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final taught = _taughtBefore(stop, journey);
    return switch (stop.kind) {
      StopKind.lesson => _lesson(stop, rng),
      StopKind.review => [
          ..._questions(taught, journey, rng, count: 6),
          if (taught.length >= 3) _match(taught, rng),
        ],
      StopKind.checkpoint => [
          ..._questions(taught, journey, rng, count: 6),
          ...stop.exercises,
        ],
    };
  }

  static List<LessonStep> _lesson(PathStop stop, Random rng) {
    final dialogues = stop.exercises.whereType<DialogueStep>().toList();
    final others = stop.exercises.where((e) => e is! DialogueStep).toList();
    return [
      for (final item in stop.items) LearnStep(item),
      ...others,
      if (stop.items.length >= 3) _match(stop.items, rng),
      ...dialogues,
    ];
  }

  /// Every item taught in the same week, before [stop].
  static List<PathItem> _taughtBefore(PathStop stop, List<PathStop> journey) =>
      [
        for (final s in journey)
          if (s.stage == stop.stage &&
              s.week == stop.week &&
              s.kind == StopKind.lesson &&
              journey.indexOf(s) < journey.indexOf(stop))
            ...s.items,
      ];

  static MatchStep _match(List<PathItem> items, Random rng) {
    final pick = [...items]..shuffle(rng);
    return MatchStep([for (final i in pick.take(4)) (i.fr, i.es)]);
  }

  /// Questions about [items], for the review of mistakes.
  static List<LessonStep> questionsAbout(
    List<PathItem> items,
    List<PathStop> journey, {
    Random? random,
  }) =>
      _questions(items, journey, random ?? Random(), count: items.length);

  /// Alternating "what does it mean" and "what did you hear" questions,
  /// with wrong options from the rest of the week (or the journey).
  static List<LessonStep> _questions(
    List<PathItem> items,
    List<PathStop> journey,
    Random rng, {
    required int count,
  }) {
    if (items.isEmpty) return const [];
    final everything = [for (final s in journey) ...s.items];
    final pick = [...items]..shuffle(rng);
    final out = <LessonStep>[];
    for (final (i, item) in pick.take(count).indexed) {
      final pool = {
        for (final o in [...items, ...everything])
          if (o.es != item.es) o.es,
      }.toList()
        ..shuffle(rng);
      final options = [item.es, ...pool.take(3)]..shuffle(rng);
      final answer = options.indexOf(item.es);
      out.add(i.isEven
          ? ChoiceStep(
              prompt: '¿Qué significa «${item.fr}»?',
              options: options,
              answer: answer,
              about: item.fr,
            )
          : ListenStep(fr: item.fr, options: options, answer: answer));
    }
    return out;
  }
}
