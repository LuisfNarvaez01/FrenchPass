import 'package:french_pass/features/tutor/domain/saved_session.dart';

/// A Spanish sentence taken apart in French: the translation, each word of
/// it, and the other ways a French speaker might put the same idea.
class Translation {
  final String id;
  final DateTime date;

  /// What the learner typed.
  final String sourceEs;

  /// The translation a French speaker would actually say.
  final String fr;

  /// [fr] back into Spanish word for word, so the French structure shows.
  final String literalEs;

  /// Every word of [fr], in order.
  final List<WordGloss> words;

  /// Other ways to say it: more casual, more formal, more idiomatic.
  final List<PhraseAlternative> alternatives;

  /// Grammar worth noticing in this sentence, one short note each.
  final List<String> notesEs;

  const Translation({
    required this.id,
    required this.date,
    required this.sourceEs,
    required this.fr,
    this.literalEs = '',
    this.words = const [],
    this.alternatives = const [],
    this.notesEs = const [],
  });

  factory Translation.fromJson(Map<String, dynamic> json) => Translation(
        id: json['id'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        sourceEs: (json['sourceEs'] as String? ?? '').trim(),
        fr: (json['fr'] as String? ?? '').trim(),
        literalEs: (json['literalEs'] as String? ?? '').trim(),
        words: [
          for (final w in json['words'] as List? ?? const [])
            if (w is Map<String, dynamic>) WordGloss.fromJson(w),
        ].where((w) => w.word.isNotEmpty).toList(),
        alternatives: [
          for (final a in json['alternatives'] as List? ?? const [])
            if (a is Map<String, dynamic>) PhraseAlternative.fromJson(a),
        ].where((a) => a.fr.isNotEmpty).toList(),
        notesEs: [
          for (final n in json['notesEs'] as List? ?? const [])
            if (n is String && n.trim().isNotEmpty) n.trim(),
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'sourceEs': sourceEs,
        'fr': fr,
        'literalEs': literalEs,
        'words': [for (final w in words) w.toJson()],
        'alternatives': [for (final a in alternatives) a.toJson()],
        'notesEs': notesEs,
      };

  /// The gloss for a token of [fr]; see [LineStudy.glossFor].
  WordGloss? glossFor(String token) =>
      LineStudy(translationEs: '', words: words).glossFor(token);
}

class PhraseAlternative {
  /// "Más natural", "Coloquial", "Formal"…
  final String register;
  final String fr;
  final String es;

  /// When to use it, or what changes against the main translation.
  final String noteEs;

  const PhraseAlternative({
    required this.register,
    required this.fr,
    this.es = '',
    this.noteEs = '',
  });

  factory PhraseAlternative.fromJson(Map<String, dynamic> json) =>
      PhraseAlternative(
        register: (json['register'] as String? ?? '').trim(),
        fr: (json['fr'] as String? ?? '').trim(),
        es: (json['es'] as String? ?? '').trim(),
        noteEs: (json['noteEs'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() =>
      {'register': register, 'fr': fr, 'es': es, 'noteEs': noteEs};
}
