import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

enum QuizMode {
  /// French word shown, pick the Spanish meaning.
  frToEs,

  /// Spanish meaning shown, pick the French word.
  esToFr,

  /// Word played aloud, pick the French spelling.
  audio,

  /// IPA transcription shown, pick the French word.
  ipa,
}

extension QuizModeExtension on QuizMode {
  String get promptEs => switch (this) {
        QuizMode.frToEs => '¿Qué significa?',
        QuizMode.esToFr => '¿Cómo se dice en francés?',
        QuizMode.audio => '¿Qué palabra escuchaste?',
        QuizMode.ipa => '¿Qué palabra se transcribe así?',
      };

  bool get needsAudio => this == QuizMode.audio;
}

class QuizQuestion {
  final Word target;
  final QuizMode mode;

  /// Four options including the correct one, already shuffled.
  final List<Word> options;

  const QuizQuestion({
    required this.target,
    required this.mode,
    required this.options,
  });

  int get correctIndex => options.indexWhere((w) => w.id == target.id);

  /// What the question shows.
  String get prompt => switch (mode) {
        QuizMode.frToEs => target.french,
        QuizMode.esToFr => target.translationEs,
        QuizMode.audio => '🔊',
        QuizMode.ipa => target.ipa,
      };

  /// How each option is labelled.
  String labelFor(Word option) => switch (mode) {
        QuizMode.frToEs => option.translationEs,
        QuizMode.esToFr => option.french,
        QuizMode.audio => option.french,
        QuizMode.ipa => option.french,
      };
}

/// One answered question.
class QuizAnswer {
  final QuizQuestion question;
  final int selectedIndex;

  const QuizAnswer({required this.question, required this.selectedIndex});

  bool get isCorrect => selectedIndex == question.correctIndex;
  Word get selected => question.options[selectedIndex];
}
