import 'package:equatable/equatable.dart';

class SrsCard extends Equatable {
  final String wordId;
  final int repetitions;
  final double easinessFactor; // SM-2: 1.3 – 2.5 (default 2.5)
  final int intervalDays;
  final DateTime nextReviewDate;
  final DateTime? lastReviewDate;
  final double? lastScore;

  const SrsCard({
    required this.wordId,
    this.repetitions = 0,
    this.easinessFactor = 2.5,
    this.intervalDays = 1,
    required this.nextReviewDate,
    this.lastReviewDate,
    this.lastScore,
  });

  bool get isDueToday {
    final now = DateTime.now();
    final due = nextReviewDate;
    // Due if the scheduled day is today or already past.
    return !DateTime(due.year, due.month, due.day)
        .isAfter(DateTime(now.year, now.month, now.day));
  }

  int get daysUntilReview {
    final now = DateTime.now();
    return DateTime(nextReviewDate.year, nextReviewDate.month,
            nextReviewDate.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  SrsCard copyWith({
    int? repetitions,
    double? easinessFactor,
    int? intervalDays,
    DateTime? nextReviewDate,
    DateTime? lastReviewDate,
    double? lastScore,
  }) =>
      SrsCard(
        wordId: wordId,
        repetitions: repetitions ?? this.repetitions,
        easinessFactor: easinessFactor ?? this.easinessFactor,
        intervalDays: intervalDays ?? this.intervalDays,
        nextReviewDate: nextReviewDate ?? this.nextReviewDate,
        lastReviewDate: lastReviewDate ?? this.lastReviewDate,
        lastScore: lastScore ?? this.lastScore,
      );

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'repetitions': repetitions,
        'easinessFactor': easinessFactor,
        'intervalDays': intervalDays,
        'nextReviewDate': nextReviewDate.toIso8601String(),
        'lastReviewDate': lastReviewDate?.toIso8601String(),
        'lastScore': lastScore,
      };

  static SrsCard? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final wordId = json['wordId'];
    final nextReview = DateTime.tryParse('${json['nextReviewDate']}');
    if (wordId is! String || nextReview == null) return null;

    final lastScore = json['lastScore'];
    return SrsCard(
      wordId: wordId,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      easinessFactor: (json['easinessFactor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 1,
      nextReviewDate: nextReview,
      lastReviewDate: DateTime.tryParse('${json['lastReviewDate']}'),
      lastScore: lastScore is num ? lastScore.toDouble() : null,
    );
  }

  @override
  List<Object?> get props => [wordId, repetitions, intervalDays, nextReviewDate];
}
