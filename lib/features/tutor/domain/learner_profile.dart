/// What the tutor has learned about this learner across sessions.
///
/// Rewritten by the model after every lesson (see `TutorReviewService`) and
/// fed back into the next lesson's instructions, so the tutor keeps
/// steering towards the same weak spots instead of starting cold each time.
class LearnerProfile {
  /// The tutor's own estimate, e.g. "A1", "A2+".
  final String levelEstimate;

  /// Recurring mistakes, most important first. Each is one short line in
  /// Spanish, e.g. "Usa 'je veux' en vez de 'je voudrais' para pedir".
  final List<String> recurringMistakes;

  /// Sounds or words the learner keeps mispronouncing.
  final List<String> pronunciation;

  /// Things the learner already does well, so the tutor can push past them.
  final List<String> strengths;

  /// Free-form personal context the learner shared (job, interests…) that
  /// makes conversations feel like they know you. Spanish.
  final List<String> personalNotes;

  final int sessions;

  const LearnerProfile({
    this.levelEstimate = '',
    this.recurringMistakes = const [],
    this.pronunciation = const [],
    this.strengths = const [],
    this.personalNotes = const [],
    this.sessions = 0,
  });

  static const empty = LearnerProfile();

  bool get isEmpty =>
      sessions == 0 &&
      recurringMistakes.isEmpty &&
      pronunciation.isEmpty &&
      strengths.isEmpty &&
      personalNotes.isEmpty;

  // Bounded so the profile never grows into a prompt-sized liability.
  static const _maxItems = 8;

  static List<String> _strings(Object? raw) => raw is List
      ? raw
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(_maxItems)
          .toList()
      : const [];

  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
        levelEstimate: (json['levelEstimate'] as String?)?.trim() ?? '',
        recurringMistakes: _strings(json['recurringMistakes']),
        pronunciation: _strings(json['pronunciation']),
        strengths: _strings(json['strengths']),
        personalNotes: _strings(json['personalNotes']),
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'levelEstimate': levelEstimate,
        'recurringMistakes': recurringMistakes,
        'pronunciation': pronunciation,
        'strengths': strengths,
        'personalNotes': personalNotes,
        'sessions': sessions,
      };

  LearnerProfile copyWith({int? sessions, String? levelEstimate}) =>
      LearnerProfile(
        levelEstimate: levelEstimate ?? this.levelEstimate,
        recurringMistakes: recurringMistakes,
        pronunciation: pronunciation,
        strengths: strengths,
        personalNotes: personalNotes,
        sessions: sessions ?? this.sessions,
      );
}

/// A finished lesson, kept so the tutor screen can show progress and the
/// next session can avoid repeating itself.
class LessonRecord {
  final String lessonId;
  final DateTime date;
  final bool goalReached;
  final int corrections;
  final String summaryEs;

  const LessonRecord({
    required this.lessonId,
    required this.date,
    required this.goalReached,
    required this.corrections,
    required this.summaryEs,
  });

  factory LessonRecord.fromJson(Map<String, dynamic> json) => LessonRecord(
        lessonId: json['lessonId'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        goalReached: json['goalReached'] as bool? ?? false,
        corrections: (json['corrections'] as num?)?.toInt() ?? 0,
        summaryEs: json['summaryEs'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'date': date.toIso8601String(),
        'goalReached': goalReached,
        'corrections': corrections,
        'summaryEs': summaryEs,
      };
}
