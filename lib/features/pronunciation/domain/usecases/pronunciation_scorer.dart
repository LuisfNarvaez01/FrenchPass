import 'package:french_pass/features/pronunciation/domain/entities/pronunciation_result.dart';

/// Scores a spoken attempt against the target word on three axes:
///
/// 1. **Claridad** — normalised Levenshtein distance on the written forms.
/// 2. **Acento** — the same distance on a simplified French phonetic form, so
///    a learner who says the right sounds is not penalised for the spelling
///    the recognizer chose.
/// 3. **Ritmo** — syllable-count agreement.
class PronunciationScorer {
  PronunciationScorer._();

  static PronunciationResult score({
    required String targetWord,
    required String recognizedText,
  }) {
    final target = _normalize(targetWord);
    final recognized = _normalize(recognizedText);

    final clarityScore = _similarity(target, recognized);

    final accentScore = _similarity(
      _frenchPhonetic(target),
      _frenchPhonetic(recognized),
    );

    final targetSyllables = _countSyllables(target);
    final recognizedSyllables = _countSyllables(recognized);
    final syllableDiff = (targetSyllables - recognizedSyllables).abs();
    final rhythmScore =
        (1.0 - syllableDiff / (targetSyllables == 0 ? 1 : targetSyllables))
            .clamp(0.0, 1.0);

    final overall =
        (clarityScore * 0.5 + accentScore * 0.3 + rhythmScore * 0.2)
            .clamp(0.0, 1.0);

    return PronunciationResult(
      recognizedText: recognizedText,
      overallScore: overall,
      clarityScore: clarityScore,
      accentScore: accentScore,
      rhythmScore: rhythmScore,
      feedback: _feedbackFor(overall),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// 1.0 for identical strings, 0.0 for nothing in common.
  static double _similarity(String a, String b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return (1.0 - _levenshtein(a, b) / maxLen).clamp(0.0, 1.0);
  }

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('œ', 'oe')
      .replaceAll(RegExp(r"['’\-]"), ' ')
      .replaceAll(RegExp(r'[^a-z ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Rough grapheme-to-sound mapping for French.
  ///
  /// Digraph order matters: the longest sequences are rewritten first, so
  /// "eau" becomes a single /o/ instead of being eaten by the "eu" and "au"
  /// rules. Final silent consonants are dropped last, since that is where
  /// French spelling and French sound diverge most.
  static String _frenchPhonetic(String text) {
    var out = text;

    // Three-letter sequences first.
    const trigraphs = {
      'eau': 'o',
      'ain': '5', // nasal /ɛ̃/
      'ein': '5',
      'oin': '6', // nasal /wɛ̃/
      'ill': 'j',
      'gue': 'g',
      'qui': 'ki',
      'que': 'k',
    };
    trigraphs.forEach((from, to) => out = out.replaceAll(from, to));

    // Then two-letter sequences.
    const digraphs = {
      'ph': 'f',
      'ch': 'S',
      'gn': 'N',
      'qu': 'k',
      'oi': 'wa',
      'ou': 'u',
      'eu': '2', // /ø/
      'au': 'o',
      'ai': 'e',
      'ei': 'e',
      'an': '1', // nasal /ɑ̃/
      'am': '1',
      'en': '1',
      'em': '1',
      'in': '5',
      'im': '5',
      'on': '3', // nasal /ɔ̃/
      'om': '3',
      'un': '4', // nasal /œ̃/
      'ss': 's',
      'th': 't',
      'll': 'l',
      'mm': 'm',
      'nn': 'n',
      'tt': 't',
      'pp': 'p',
      'rr': 'r',
      'cc': 'k',
    };
    digraphs.forEach((from, to) => out = out.replaceAll(from, to));

    // Single letters that are never pronounced as written.
    out = out.replaceAll('y', 'i');
    out = out.replaceAll('h', '');

    // Final silent consonants and the silent final -e, per word.
    out = out
        .split(' ')
        .map((word) {
          var w = word;
          if (w.length > 1) {
            w = w.replaceFirst(RegExp(r'(?:es|ent|[edstxz])$'), '');
          }
          return w;
        })
        .where((w) => w.isNotEmpty)
        .join(' ');

    return out;
  }

  static int _countSyllables(String text) {
    // Vowel groups approximate French syllable count closely enough for a
    // rhythm signal.
    return RegExp(r'[aeiouy]+').allMatches(text).length;
  }

  /// Two-row Levenshtein: the full matrix is unnecessary here and this keeps
  /// allocation proportional to the shorter string.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }

  static PronunciationFeedback _feedbackFor(double score) => switch (score) {
        >= 0.90 => PronunciationFeedback.parfait,
        >= 0.75 => PronunciationFeedback.tresBien,
        >= 0.55 => PronunciationFeedback.biensur,
        _ => PronunciationFeedback.reessaie,
      };
}
