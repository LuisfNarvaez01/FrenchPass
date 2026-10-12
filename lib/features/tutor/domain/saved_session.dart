import 'package:french_pass/features/tutor/domain/tutor_message.dart';

/// A finished conversation with the tutor, kept on the phone so the learner
/// can go back over it line by line after the call has ended.
///
/// The study material for each line ([LineStudy]) is fetched lazily, the
/// first time the learner opens that line, and then stored here too: going
/// over the same session again costs nothing.
class SavedSession {
  final String id;
  final String lessonId;
  final DateTime date;
  final bool goalReached;
  final List<TutorMessage> messages;
  final String summaryEs;

  /// By message index.
  final Map<int, LineStudy> studies;

  const SavedSession({
    required this.id,
    required this.lessonId,
    required this.date,
    required this.goalReached,
    required this.messages,
    this.summaryEs = '',
    this.studies = const {},
  });

  /// Lines worth studying: anything actually said, by either side.
  int get spokenLines =>
      messages.where((m) => m.text.trim().isNotEmpty).length;

  SavedSession withStudy(int index, LineStudy study) => SavedSession(
        id: id,
        lessonId: lessonId,
        date: date,
        goalReached: goalReached,
        messages: messages,
        summaryEs: summaryEs,
        studies: {...studies, index: study},
      );

  factory SavedSession.fromJson(Map<String, dynamic> json) {
    final studies = <int, LineStudy>{};
    final rawStudies = json['studies'];
    if (rawStudies is Map<String, dynamic>) {
      rawStudies.forEach((key, value) {
        final i = int.tryParse(key);
        if (i != null && value is Map<String, dynamic>) {
          studies[i] = LineStudy.fromJson(value);
        }
      });
    }
    return SavedSession(
      id: json['id'] as String? ?? '',
      lessonId: json['lessonId'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      goalReached: json['goalReached'] as bool? ?? false,
      messages: [
        for (final m in json['messages'] as List? ?? const [])
          if (tutorMessageFromJson(m) case final TutorMessage message) message,
      ],
      summaryEs: json['summaryEs'] as String? ?? '',
      studies: studies,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lessonId': lessonId,
        'date': date.toIso8601String(),
        'goalReached': goalReached,
        'messages': [for (final m in messages) tutorMessageToJson(m)],
        'summaryEs': summaryEs,
        'studies': {
          for (final e in studies.entries) '${e.key}': e.value.toJson(),
        },
      };
}

/// Everything the review screen shows for one line: what it means, each
/// word on its own, and -- for the tutor's lines -- ways to answer it.
class LineStudy {
  final String translationEs;
  final List<WordGloss> words;

  /// Tutor lines only: answers from simplest to most natural.
  final List<ReplyOption> replies;

  /// Learner lines only: the same idea said the way a French speaker would.
  final String betterFr;
  final String betterNoteEs;

  const LineStudy({
    required this.translationEs,
    this.words = const [],
    this.replies = const [],
    this.betterFr = '',
    this.betterNoteEs = '',
  });

  factory LineStudy.fromJson(Map<String, dynamic> json) => LineStudy(
        translationEs: (json['translationEs'] as String? ?? '').trim(),
        words: [
          for (final w in json['words'] as List? ?? const [])
            if (w is Map<String, dynamic>) WordGloss.fromJson(w),
        ].where((w) => w.word.isNotEmpty).toList(),
        replies: [
          for (final r in json['replies'] as List? ?? const [])
            if (r is Map<String, dynamic>) ReplyOption.fromJson(r),
        ].where((r) => r.fr.isNotEmpty).toList(),
        betterFr: (json['betterFr'] as String? ?? '').trim(),
        betterNoteEs: (json['betterNoteEs'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {
        'translationEs': translationEs,
        'words': [for (final w in words) w.toJson()],
        'replies': [for (final r in replies) r.toJson()],
        if (betterFr.isNotEmpty) 'betterFr': betterFr,
        if (betterNoteEs.isNotEmpty) 'betterNoteEs': betterNoteEs,
      };

  /// The gloss for a token as it appears in the line, matched loosely
  /// (case, elision and punctuation differ between the transcript and the
  /// model's answer).
  WordGloss? glossFor(String token) {
    final key = WordGloss.normalize(token);
    if (key.isEmpty) return null;
    for (final w in words) {
      if (WordGloss.normalize(w.word) == key) return w;
    }
    // "l'eau" in the line, "eau" in the gloss list (or the reverse).
    for (final w in words) {
      final g = WordGloss.normalize(w.word);
      if (g.isNotEmpty && (key.endsWith(g) || g.endsWith(key))) return w;
    }
    return null;
  }
}

class WordGloss {
  final String word;
  final String ipa;
  final String meaningEs;

  /// Grammar in a few words: "verbo aller, 1ª persona", "femenino"…
  final String noteEs;

  const WordGloss({
    required this.word,
    this.ipa = '',
    this.meaningEs = '',
    this.noteEs = '',
  });

  factory WordGloss.fromJson(Map<String, dynamic> json) => WordGloss(
        word: (json['word'] as String? ?? '').trim(),
        ipa: (json['ipa'] as String? ?? '').trim(),
        meaningEs: (json['meaningEs'] as String? ?? '').trim(),
        noteEs: (json['noteEs'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'ipa': ipa,
        'meaningEs': meaningEs,
        'noteEs': noteEs,
      };

  static String normalize(String token) => token
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true), '')
      .trim();
}

class ReplyOption {
  /// CEFR-ish label: "A1", "A2", "B1"…
  final String level;
  final String fr;
  final String es;

  const ReplyOption({required this.level, required this.fr, this.es = ''});

  factory ReplyOption.fromJson(Map<String, dynamic> json) => ReplyOption(
        level: (json['level'] as String? ?? '').trim(),
        fr: (json['fr'] as String? ?? '').trim(),
        es: (json['es'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {'level': level, 'fr': fr, 'es': es};
}
