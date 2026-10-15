/// The learning journey: seven stages from zero to mastery, each a stop on
/// a trip through France. The CEFR level is shown as the official measure;
/// the stage is what the learner lives.
enum Stage {
  depart(
    'depart',
    'Départ',
    'Desde cero',
    'Saludar, despedirte y decir tu nombre. Tus primeras 30 palabras.',
    null,
  ),
  premiersPas(
    'premiers',
    'Premiers pas',
    'Principiante',
    'Presentarte, contar y decir qué te gusta, en frases cortas.',
    'A1 inicial',
  ),
  auCafe(
    'cafe',
    'Au café',
    'Básico',
    'Pedir, preguntar precios y caminos, y hablar de tu día.',
    'A1',
  ),
  enVille(
    'ville',
    'En ville',
    'Pre-intermedio',
    'Contar lo que hiciste, hacer planes y resolver problemas sencillos.',
    'A2',
  ),
  conversations(
    'conversations',
    'Conversations',
    'Intermedio',
    'Dar tu opinión, contar una historia y charlar cinco minutos.',
    'B1',
  ),
  debats(
    'debats',
    'Débats',
    'Intermedio avanzado',
    'Argumentar, matizar y entender noticias sin subtítulos.',
    'B2',
  ),
  parisien(
    'parisien',
    'Comme un Parisien',
    'Avanzado y dominio',
    'Registro formal e informal, expresiones e ironía.',
    'C1–C2',
  );

  /// Short id: the stage's file name and the prefix of its stop ids.
  final String key;
  final String nameFr;
  final String nameEs;

  /// What the learner can do at the end, as a "can do" statement.
  final String canDoEs;

  /// The CEFR level it matches, if any.
  final String? cefr;

  const Stage(this.key, this.nameFr, this.nameEs, this.canDoEs, this.cefr);

  static Stage? parse(String? raw) {
    for (final s in Stage.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// A word or phrase a lesson teaches.
class PathItem {
  final String fr;
  final String ipa;
  final String es;
  final String exampleFr;
  final String exampleEs;

  const PathItem({
    required this.fr,
    required this.ipa,
    required this.es,
    this.exampleFr = '',
    this.exampleEs = '',
  });

  factory PathItem.fromJson(Map<String, dynamic> j) => PathItem(
        fr: j['fr'] as String,
        ipa: j['ipa'] as String? ?? '',
        es: j['es'] as String,
        exampleFr: j['exFr'] as String? ?? '',
        exampleEs: j['exEs'] as String? ?? '',
      );
}

/// One screen of a lesson.
sealed class LessonStep {
  const LessonStep();

  static LessonStep fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'choice' => ChoiceStep(
            prompt: j['prompt'] as String,
            options: (j['options'] as List).cast<String>(),
            answer: j['answer'] as int,
            why: j['why'] as String? ?? '',
          ),
        'listen' => ListenStep(
            fr: j['fr'] as String,
            options: (j['options'] as List).cast<String>(),
            answer: j['answer'] as int,
          ),
        'order' => OrderStep(fr: j['fr'] as String, es: j['es'] as String),
        'dialogue' => DialogueStep([
            for (final l in (j['lines'] as List).cast<Map<String, dynamic>>())
              DialogueLine.fromJson(l),
          ]),
        final t => throw FormatException('Unknown lesson step: $t'),
      };
}

/// Meet a new word: its sound, meaning and an example.
class LearnStep extends LessonStep {
  final PathItem item;
  const LearnStep(this.item);
}

/// Four options, one right.
class ChoiceStep extends LessonStep {
  final String prompt;
  final List<String> options;
  final int answer;
  final String why;

  /// The taught item this asks about, so a miss can be reviewed later.
  final String? about;

  const ChoiceStep({
    required this.prompt,
    required this.options,
    required this.answer,
    this.why = '',
    this.about,
  });
}

/// Hear French, pick what it means.
class ListenStep extends LessonStep {
  final String fr;
  final List<String> options;
  final int answer;
  const ListenStep({
    required this.fr,
    required this.options,
    required this.answer,
  });
}

/// Pair French with Spanish.
class MatchStep extends LessonStep {
  final List<(String, String)> pairs;
  const MatchStep(this.pairs);
}

/// Put the words of a sentence in order.
class OrderStep extends LessonStep {
  final String fr;
  final String es;
  const OrderStep({required this.fr, required this.es});

  /// The tiles: words and punctuation-attached words, as written.
  List<String> get tiles => fr.split(RegExp(r'\s+'));
}

/// A micro-conversation: lines from a French speaker, and the learner's
/// turns as a choice.
class DialogueStep extends LessonStep {
  final List<DialogueLine> lines;
  const DialogueStep(this.lines);

  int get turns => lines.where((l) => l.isLearner).length;
}

class DialogueLine {
  /// Who speaks, or null for the learner.
  final String? who;
  final String fr;
  final String es;
  final List<String> options;
  final int answer;

  const DialogueLine({
    this.who,
    this.fr = '',
    required this.es,
    this.options = const [],
    this.answer = 0,
  });

  bool get isLearner => who == null;

  /// What the learner says, once they have picked right.
  String get said => isLearner ? options[answer] : fr;

  factory DialogueLine.fromJson(Map<String, dynamic> j) => j['you'] == true
      ? DialogueLine(
          es: j['es'] as String? ?? '',
          options: (j['options'] as List).cast<String>(),
          answer: j['answer'] as int? ?? 0,
        )
      : DialogueLine(
          who: j['who'] as String,
          fr: j['fr'] as String,
          es: j['es'] as String? ?? '',
        );
}

enum StopKind { lesson, review, checkpoint }

/// A stop on the journey: a lesson, the week's review, or the week's
/// checkpoint.
class PathStop {
  final String id;
  final Stage stage;
  final int week;
  final StopKind kind;
  final String titleEs;
  final String goalEs;
  final List<PathItem> items;
  final List<LessonStep> exercises;

  /// A tutor lesson that makes a spoken version of the checkpoint.
  final String? tutorLessonId;

  const PathStop({
    required this.id,
    required this.stage,
    required this.week,
    required this.kind,
    required this.titleEs,
    required this.goalEs,
    this.items = const [],
    this.exercises = const [],
    this.tutorLessonId,
  });

  factory PathStop.fromJson(Map<String, dynamic> j) => PathStop(
        id: j['id'] as String,
        stage: Stage.parse(j['stage'] as String?) ??
            (throw FormatException('Unknown stage in ${j['id']}')),
        week: j['week'] as int? ?? 1,
        kind: StopKind.values.byName(j['kind'] as String? ?? 'lesson'),
        titleEs: j['title'] as String,
        goalEs: j['goal'] as String? ?? '',
        items: [
          for (final i
              in (j['items'] as List? ?? const []).cast<Map<String, dynamic>>())
            PathItem.fromJson(i),
        ],
        exercises: [
          for (final e in (j['exercises'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
            LessonStep.fromJson(e),
        ],
        tutorLessonId: j['tutor'] as String?,
      );

  /// The word that opens this stop: the word of the day while it is next.
  PathItem? get keyItem => items.isEmpty ? null : items.first;
}
