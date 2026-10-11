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
