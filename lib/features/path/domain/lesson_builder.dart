import 'dart:math';

import 'package:french_pass/features/path/domain/journey.dart';

/// Turns a stop into the screens the learner goes through.
///
/// A lesson teaches its words one by one, then practises them (the authored
/// exercises, a matching round) and ends on the micro-conversation, the
/// small win. A review and a checkpoint are built from the week's lessons,
/// so they always cover exactly what was taught. Options are shuffled every
/// time, so a repeated lesson can't be passed from memory of positions.
abstract final class LessonBuilder {
  static List<LessonStep> build(
    PathStop stop,
    List<PathStop> journey, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final week = _weekLessons(stop, journey);
    final taught = [for (final s in week) ...s.items];
    final steps = switch (stop.kind) {
      StopKind.lesson => _lesson(stop, rng),
      StopKind.review => [
          ..._questions(taught, journey, rng, count: 8),
          if (taught.length >= 3) _match(taught, rng),
        ],
      StopKind.checkpoint => [
          ..._questions(taught, journey, rng, count: 6),
          ..._orders(week, rng, count: 2),
          ..._checkpointDialogue(stop, week),
        ],
    };
    return [for (final s in steps) _shuffled(s, rng)];
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

  /// The lessons of [stop]'s week that come before it.
  static List<PathStop> _weekLessons(PathStop stop, List<PathStop> journey) {
    final at = journey.indexOf(stop);
    return [
      for (final (i, s) in journey.indexed)
        if (i < at &&
            s.stage == stop.stage &&
            s.week == stop.week &&
            s.kind == StopKind.lesson)
          s,
    ];
  }

  /// The checkpoint's own conversation, or the week's longest one.
  static List<LessonStep> _checkpointDialogue(
      PathStop stop, List<PathStop> week) {
    final own = stop.exercises.whereType<DialogueStep>().toList();
    if (own.isNotEmpty) return own;
    final all = [
      for (final s in week) ...s.exercises.whereType<DialogueStep>(),
    ]..sort((a, b) => b.turns.compareTo(a.turns));
    return all.isEmpty ? const [] : [all.first];
  }

  static List<LessonStep> _orders(List<PathStop> week, Random rng,
      {required int count}) {
    final all = [
      for (final s in week) ...s.exercises.whereType<OrderStep>(),
    ]..shuffle(rng);
    return all.take(count).toList();
  }

  static MatchStep _match(List<PathItem> items, Random rng) {
    final pick = [...items]..shuffle(rng);
    final seen = <String>{};
    return MatchStep([
      for (final i in pick)
        if (seen.add(i.es)) (i.fr, i.es),
    ].take(4).toList());
  }

  /// Questions about [items], for the review of mistakes.
  static List<LessonStep> questionsAbout(
    List<PathItem> items,
    List<PathStop> journey, {
    Random? random,
  }) {
    final rng = random ?? Random();
    return [
      for (final s in _questions(items, journey, rng, count: items.length))
        _shuffled(s, rng),
    ];
  }

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
      final options = [item.es, ...pool.take(3)];
      out.add(i.isEven
          ? ChoiceStep(
              prompt: '¿Qué significa «${item.fr}»?',
              options: options,
              answer: 0,
              about: item.fr,
            )
          : ListenStep(fr: item.fr, options: options, answer: 0));
    }
    return out;
  }

  /// The same step with its options in a new order.
  static LessonStep _shuffled(LessonStep step, Random rng) {
    (List<String>, int) mix(List<String> options, int answer) {
      final right = options[answer];
      final out = [...options]..shuffle(rng);
      return (out, out.indexOf(right));
    }

    switch (step) {
      case ChoiceStep():
        final (o, a) = mix(step.options, step.answer);
        return ChoiceStep(
            prompt: step.prompt,
            options: o,
            answer: a,
            why: step.why,
            about: step.about);
      case ListenStep():
        final (o, a) = mix(step.options, step.answer);
        return ListenStep(fr: step.fr, options: o, answer: a);
      case DialogueStep():
        return DialogueStep([
          for (final l in step.lines)
            if (!l.isLearner)
              l
            else
              () {
                final (o, a) = mix(l.options, l.answer);
                return DialogueLine(es: l.es, options: o, answer: a);
              }(),
        ]);
      default:
        return step;
    }
  }
}
