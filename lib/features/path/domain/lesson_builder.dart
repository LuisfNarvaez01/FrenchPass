import 'dart:math';

import 'package:french_pass/features/path/domain/journey.dart';

/// Turns a stop into the screens the learner goes through.
///
/// A lesson teaches its words two at a time, each pair followed by a quick
/// check, then practises all of them: the authored exercises, "how do you
/// say…", saying words aloud, a matching round, and it ends on the
/// conversation, the small win. A review and a checkpoint are built from the
/// week's lessons, so they always cover exactly what was taught. Options are
/// shuffled every time, so a repeated lesson can't be passed from memory of
/// positions.
abstract final class LessonBuilder {
  static List<LessonStep> build(
    PathStop stop,
    List<PathStop> journey, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final week = _weekLessons(stop, journey);
    final taught = [for (final s in week) ...s.items];
    final everything = [for (final s in journey) ...s.items];
    final steps = switch (stop.kind) {
      StopKind.lesson => _lesson(stop, everything, rng),
      StopKind.review => [
          ..._questions(taught, everything, rng, count: 8),
          ..._sayings(taught, everything, rng, count: 2),
          ..._speaking(taught, rng, count: 2),
          if (taught.length >= 3) _match(taught, rng),
        ],
      StopKind.checkpoint => [
          ..._questions(taught, everything, rng, count: 6),
          ..._orders(week, rng, count: 2),
          ..._speaking(taught, rng, count: 2),
          ..._checkpointDialogue(stop, week),
        ],
    };
    return [for (final s in steps) _shuffled(s, rng)];
  }

  /// A second chance at a missed step, with its options in a new order.
  static LessonStep again(LessonStep step, {Random? random}) =>
      _shuffled(step, random ?? Random());

  static List<LessonStep> _lesson(
      PathStop stop, List<PathItem> everything, Random rng) {
    final items = stop.items;
    final dialogues = stop.exercises.whereType<DialogueStep>().toList();
    final authored = stop.exercises.where((e) => e is! DialogueStep).toList();
    final steps = <LessonStep>[];
    for (var i = 0; i < items.length; i++) {
      steps.add(LearnStep(items[i]));
      final pairDone = i.isOdd || i == items.length - 1;
      if (!pairDone) continue;
      // A quick check on one word of the pair, alternating the kind.
      final item = items[i.isOdd ? i - 1 + rng.nextInt(2) : i];
      steps.add((i ~/ 2).isEven
          ? _meaning(item, items, everything, rng)
          : _heard(item, items, everything, rng));
    }
    return [
      ...steps,
      ...authored,
      ..._sayings(items, everything, rng, count: 2),
      ..._speaking(items, rng, count: 3),
      if (items.length >= 3) _match(items, rng),
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
    final everything = [for (final s in journey) ...s.items];
    return [
      for (final s in _questions(items, everything, rng, count: items.length))
        _shuffled(s, rng),
    ];
  }

  /// Alternating "what does it mean" and "what did you hear" questions.
  static List<LessonStep> _questions(
    List<PathItem> items,
    List<PathItem> everything,
    Random rng, {
    required int count,
  }) {
    final pick = [...items]..shuffle(rng);
    return [
      for (final (i, item) in pick.take(count).indexed)
        i.isEven
            ? _meaning(item, items, everything, rng)
            : _heard(item, items, everything, rng),
    ];
  }

  /// "How do you say…": Spanish prompt, French options.
  static List<LessonStep> _sayings(
    List<PathItem> items,
    List<PathItem> everything,
    Random rng, {
    required int count,
  }) {
    final pick = [...items]..shuffle(rng);
    return [
      for (final item in pick.take(count))
        ChoiceStep(
          prompt: '¿Cómo se dice «${item.es}»?',
          options: [
            item.fr,
            ..._wrong(item, items, everything, rng, (o) => o.fr)
          ],
          answer: 0,
          about: item.fr,
          french: true,
        ),
    ];
  }

  /// Words to say aloud, the shortest first: a long phrase is a poor first
  /// thing to say into a microphone.
  static List<LessonStep> _speaking(List<PathItem> items, Random rng,
      {required int count}) {
    final pick = [...items]..shuffle(rng);
    pick.sort((a, b) => _words(a.fr).compareTo(_words(b.fr)));
    final short = pick.where((i) => _words(i.fr) <= 8).take(count).toList()
      ..shuffle(rng);
    return [
      for (final item in short)
        SpeakStep(fr: item.fr, es: item.es, ipa: item.ipa),
    ];
  }

  static int _words(String s) => s.trim().split(RegExp(r'\s+')).length;

  static ChoiceStep _meaning(PathItem item, List<PathItem> items,
          List<PathItem> everything, Random rng) =>
      ChoiceStep(
        prompt: '¿Qué significa «${item.fr}»?',
        options: [
          item.es,
          ..._wrong(item, items, everything, rng, (o) => o.es)
        ],
        answer: 0,
        about: item.fr,
      );

  static ListenStep _heard(PathItem item, List<PathItem> items,
          List<PathItem> everything, Random rng) =>
      ListenStep(
        fr: item.fr,
        options: [
          item.es,
          ..._wrong(item, items, everything, rng, (o) => o.es)
        ],
        answer: 0,
      );

  /// Three wrong options, from the same lesson first, then the journey.
  static List<String> _wrong(PathItem item, List<PathItem> items,
      List<PathItem> everything, Random rng, String Function(PathItem) side) {
    final right = side(item);
    final near = {
      for (final o in items)
        if (side(o) != right && o.es != item.es) side(o),
    }.toList()
      ..shuffle(rng);
    final far = {
      for (final o in everything)
        if (side(o) != right && o.es != item.es && !near.contains(side(o)))
          side(o),
    }.toList()
      ..shuffle(rng);
    return [...near.take(2), ...far, ...near.skip(2)].take(3).toList();
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
            about: step.about,
            french: step.french);
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
