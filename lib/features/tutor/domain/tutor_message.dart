/// One line of the lesson transcript.
sealed class TutorMessage {
  const TutorMessage();
  String get text;
}

class TutorLine extends TutorMessage {
  @override
  final String text;
  const TutorLine(this.text);

  TutorLine append(String fragment) => TutorLine(joinFragment(text, fragment));
}

class LearnerLine extends TutorMessage {
  @override
  final String text;

  /// Corrections, pronunciation tips and hints shown under this line.
  final List<TutorNote> notes;

  const LearnerLine(this.text, [this.notes = const []]);

  LearnerLine append(String fragment) =>
      LearnerLine(joinFragment(text, fragment), notes);

  LearnerLine withNote(TutorNote note) => LearnerLine(text, [...notes, note]);
}

/// Transcription fragments arrive as pieces of words or whole words, with or
/// without their own leading space; join them without doubling spaces.
String joinFragment(String current, String fragment) {
  if (current.isEmpty) return fragment.trimLeft();
  if (fragment.isEmpty) return current;
  if (current.endsWith(' ') || fragment.startsWith(' ')) {
    return (current + fragment).replaceAll(RegExp(r' {2,}'), ' ');
  }
  return current + fragment;
}

/// Text the tutor puts on screen instead of saying it.
sealed class TutorNote {
  const TutorNote();
  String get kindLabel;
  String describe();
}

class CorrectionNote extends TutorNote {
  final String? originalFr;
  final String betterFr;
  final String explanationEs;
  const CorrectionNote({
    this.originalFr,
    required this.betterFr,
    required this.explanationEs,
  });

  @override
  String get kindLabel => 'corrección';
  @override
  String describe() => '$betterFr — $explanationEs';
}

class PronunciationNote extends TutorNote {
  final String wordFr;
  final String tipEs;
  const PronunciationNote({required this.wordFr, required this.tipEs});

  @override
  String get kindLabel => 'pronunciación';
  @override
  String describe() => '$wordFr — $tipEs';
}

class HintNote extends TutorNote {
  final String phraseFr;
  final String translationEs;
  const HintNote({required this.phraseFr, required this.translationEs});

  @override
  String get kindLabel => 'ayuda';
  @override
  String describe() => '$phraseFr ($translationEs)';
}

// ── Persistence ──────────────────────────────────────────────────────────────
// A finished lesson is saved so the learner can study it afterwards; these
// keep the JSON shape in one place, next to the types it mirrors.

Map<String, dynamic> tutorMessageToJson(TutorMessage message) =>
    switch (message) {
      TutorLine(:final text) => {'who': 'tutor', 'text': text},
      LearnerLine(:final text, :final notes) => {
          'who': 'learner',
          'text': text,
          if (notes.isNotEmpty)
            'notes': [for (final n in notes) tutorNoteToJson(n)],
        },
    };

TutorMessage? tutorMessageFromJson(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final text = raw['text'] as String? ?? '';
  return switch (raw['who']) {
    'tutor' => TutorLine(text),
    'learner' => LearnerLine(text, [
        for (final n in raw['notes'] as List? ?? const [])
          if (tutorNoteFromJson(n) case final TutorNote note) note,
      ]),
    _ => null,
  };
}

Map<String, dynamic> tutorNoteToJson(TutorNote note) => switch (note) {
      CorrectionNote(:final originalFr, :final betterFr, :final explanationEs) =>
        {
          'kind': 'correction',
          if (originalFr != null) 'originalFr': originalFr,
          'betterFr': betterFr,
          'explanationEs': explanationEs,
        },
      PronunciationNote(:final wordFr, :final tipEs) => {
          'kind': 'pronunciation',
          'wordFr': wordFr,
          'tipEs': tipEs,
        },
      HintNote(:final phraseFr, :final translationEs) => {
          'kind': 'hint',
          'phraseFr': phraseFr,
          'translationEs': translationEs,
        },
    };

TutorNote? tutorNoteFromJson(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  String s(String key) => raw[key] as String? ?? '';
  return switch (raw['kind']) {
    'correction' => CorrectionNote(
        originalFr: raw['originalFr'] as String?,
        betterFr: s('betterFr'),
        explanationEs: s('explanationEs'),
      ),
    'pronunciation' => PronunciationNote(wordFr: s('wordFr'), tipEs: s('tipEs')),
    'hint' => HintNote(phraseFr: s('phraseFr'), translationEs: s('translationEs')),
    _ => null,
  };
}
