import 'dart:convert';

import 'package:french_pass/features/path/domain/journey.dart';

/// Reads one stage of the journey from its compact file
/// (`assets/data/journey/<stage>.json`).
///
/// The format keeps hundreds of lessons writable by hand:
///
/// ```json
/// {
///   "stage": "auCafe",
///   "weeks": [{
///     "theme": "En el café",            // the week's subject
///     "goal": "Pedir y pagar en un café", // what the checkpoint proves
///     "tutor": "cafe",                  // optional spoken checkpoint
///     "lessons": [{
///       "t": "Pedir algo",              // title
///       "g": "Pedir con educación",     // goal
///       "i": [["je voudrais", "/ʒə vu.dʁɛ/", "quisiera",
///              "Je voudrais un thé.", "Quisiera un té."]],
///       "x": [
///         ["c", "Prompt", ["right", "wrong", "wrong", "wrong"], "why"],
///         ["l", "French heard", ["right", "wrong", "wrong", "wrong"]],
///         ["o", "French sentence.", "Spanish meaning."],
///         ["d", [["Name", "French", "Spanish"],
///                ["", ["right", "wrong", "wrong"], "Spanish of right"]]]
///       ]
///     }],
///     "cp": [ ...dialogue lines, optional... ]
///   }]
/// }
/// ```
///
/// The right option always comes first in the file; the lesson builder
/// shuffles. Each week gets five lessons, then a review and a checkpoint
/// the app builds itself, numbered `<key>-1`, `<key>-2`… so ids stay stable
/// as weeks are added after them.
abstract final class JourneyFormat {
  static List<PathStop> parseStage(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final stage = Stage.parse(json['stage'] as String?) ??
        (throw FormatException('Unknown stage: ${json['stage']}'));
    final stops = <PathStop>[];
    var n = 0;
    final weeks = (json['weeks'] as List).cast<Map<String, dynamic>>();
    for (final (w, week) in weeks.indexed) {
      final number = w + 1;
      final theme = week['theme'] as String;
      final goal = week['goal'] as String? ?? theme;
      final tutor = week['tutor'] as String?;
      for (final l in (week['lessons'] as List).cast<Map<String, dynamic>>()) {
        n++;
        stops.add(PathStop(
          id: '${stage.key}-$n',
          stage: stage,
          week: number,
          kind: StopKind.lesson,
          titleEs: l['t'] as String,
          goalEs: l['g'] as String? ?? '',
          items: [
            for (final i in (l['i'] as List).cast<List<dynamic>>()) _item(i),
          ],
          exercises: [
            for (final x in (l['x'] as List? ?? const []).cast<List<dynamic>>())
              _step(x),
          ],
        ));
      }
      n++;
      stops.add(PathStop(
        id: '${stage.key}-$n',
        stage: stage,
        week: number,
        kind: StopKind.review,
        titleEs: 'Repaso: $theme',
        goalEs: 'Fijar lo que aprendiste antes del reto',
      ));
      n++;
      stops.add(PathStop(
        id: '${stage.key}-$n',
        stage: stage,
        week: number,
        kind: StopKind.checkpoint,
        titleEs: 'Reto: $theme',
        goalEs: goal,
        tutorLessonId: tutor,
        exercises: [
          if (week['cp'] case final List<dynamic> lines)
            DialogueStep([for (final l in lines) _line(l as List<dynamic>)]),
        ],
      ));
    }
    return stops;
  }

  static PathItem _item(List<dynamic> i) => PathItem(
        fr: i[0] as String,
        ipa: i.length > 1 ? i[1] as String : '',
        es: i.length > 2 ? i[2] as String : '',
        exampleFr: i.length > 3 ? i[3] as String : '',
        exampleEs: i.length > 4 ? i[4] as String : '',
      );

  static LessonStep _step(List<dynamic> x) => switch (x[0]) {
        'c' => ChoiceStep(
            prompt: x[1] as String,
            options: (x[2] as List).cast<String>(),
            answer: 0,
            why: x.length > 3 ? x[3] as String : '',
          ),
        'l' => ListenStep(
            fr: x[1] as String,
            options: (x[2] as List).cast<String>(),
            answer: 0,
          ),
        'o' => OrderStep(fr: x[1] as String, es: x[2] as String),
        'd' => DialogueStep(
            [for (final l in x[1] as List) _line(l as List<dynamic>)]),
        final t => throw FormatException('Unknown step type: $t'),
      };

  /// `[who, fr, es]` for the other person; `["", [options], es]` for the
  /// learner, right option first.
  static DialogueLine _line(List<dynamic> l) => (l[0] as String).isEmpty
      ? DialogueLine(
          options: (l[1] as List).cast<String>(),
          es: l.length > 2 ? l[2] as String : '',
        )
      : DialogueLine(
          who: l[0] as String,
          fr: l[1] as String,
          es: l.length > 2 ? l[2] as String : '',
        );
}
