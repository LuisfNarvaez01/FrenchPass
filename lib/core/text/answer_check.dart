import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

/// How close a typed answer is to the expected one.
enum AnswerMatch {
  exact,

  /// Right letters, missing or wrong accents ("ecole" for "école").
  accents,
  wrong,
}

extension AnswerMatchX on AnswerMatch {
  /// Accents count as right: the learner knew the word; the feedback still
  /// shows the correct spelling.
  bool get isRight => this != AnswerMatch.wrong;
}

/// Compares what the learner typed with the expected French.
abstract final class AnswerCheck {
  static AnswerMatch check(String typed, String expected) {
    final answer = _clean(typed);
    if (answer.isEmpty) return AnswerMatch.wrong;
    final targets = _variants(expected);
    if (targets.contains(answer)) return AnswerMatch.exact;
    final folded = fold(answer);
    if (targets.any((t) => fold(t) == folded)) return AnswerMatch.accents;
    return AnswerMatch.wrong;
  }

  /// Lowercase, single spaces, straight apostrophes, no closing
  /// punctuation.
  static String _clean(String text) => text
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"\s*'\s*"), "'")
      .replaceAll(RegExp(r'[.!?,;:¿¡—«»"]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// "allé(e)(s)" accepts "allé", "allée", "allés", "allées" and the
  /// form as written.
  static Set<String> _variants(String expected) {
    final base = _clean(expected);
    if (!base.contains('(')) return {base};
    final out = <String>{base};
    void expand(String s) {
      final m = RegExp(r'\(([a-z]+)\)').firstMatch(s);
      if (m == null) {
        out.add(s);
        return;
      }
      expand(s.replaceRange(m.start, m.end, ''));
      expand(s.replaceRange(m.start, m.end, m.group(1)!));
    }

    expand(base);
    return out;
  }

  /// Without accents, for the "close enough" comparison.
  static String fold(String text) => WordRepository.fold(text);
}
