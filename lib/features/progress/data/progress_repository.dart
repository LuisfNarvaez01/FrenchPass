import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/progress/domain/usecases/sm2_algorithm.dart';

/// How a score was earned, so the history can be read by activity.
enum AttemptKind { pronunciation, quiz }

/// Every kind of exercise that counts towards the daily goal.
enum PracticeKind {
  quiz,
  pronunciation,
  conjugation,
  dictation,
  numbers,
  falseFriends,
  grammar,
  reading,
  order,
  match,
  placement,
  tutor,

  /// A stop on the learning journey.
  lesson,
}

/// Daily goal sizes, in exercises.
abstract final class DailyGoals {
  static const options = [10, 20, 30];
  static const fallback = 10;

  static String labelEs(int goal) => switch (goal) {
        10 => 'Tranquilo · 10 ejercicios',
        20 => 'Constante · 20 ejercicios',
        _ => 'Intenso · $goal ejercicios',
      };
}

class Attempt {
  final String wordId;
  final double score;
  final DateTime at;
  final AttemptKind kind;

  const Attempt({
    required this.wordId,
    required this.score,
    required this.at,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'score': score,
        'at': at.toIso8601String(),
        'kind': kind.name,
      };

  static Attempt? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final wordId = json['wordId'];
    final score = json['score'];
    final at = DateTime.tryParse('${json['at']}');
    if (wordId is! String || score is! num || at == null) return null;
    return Attempt(
      wordId: wordId,
      score: score.toDouble(),
      at: at,
      kind: AttemptKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => AttemptKind.pronunciation,
      ),
    );
  }
}

class QuizRun {
  final DateTime at;
  final int correct;
  final int total;

  const QuizRun({required this.at, required this.correct, required this.total});

  double get accuracy => total == 0 ? 0 : correct / total;

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'correct': correct, 'total': total};

  static QuizRun? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    final correct = json['correct'];
    final total = json['total'];
    if (at == null || correct is! num || total is! num) return null;
    return QuizRun(at: at, correct: correct.toInt(), total: total.toInt());
  }
}

/// Aggregated numbers behind the Progress screen.
class ProgressStats {
  final int wordsSeen;
  final int mastered;
  final int dueToday;
  final int totalAttempts;
  final double averageScore;
  final int currentStreak;
  final int longestStreak;
  final int favoriteCount;

  const ProgressStats({
    required this.wordsSeen,
    required this.mastered,
    required this.dueToday,
    required this.totalAttempts,
    required this.averageScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.favoriteCount,
  });

  static const empty = ProgressStats(
    wordsSeen: 0,
    mastered: 0,
    dueToday: 0,
    totalAttempts: 0,
    averageScore: 0,
    currentStreak: 0,
    longestStreak: 0,
    favoriteCount: 0,
  );
}

/// Owns every piece of persisted learner state: SRS scheduling, attempt
/// history, favourites and the study calendar.
class ProgressRepository {
  final StorageService _storage;
  ProgressRepository(this._storage);

  /// A word counts as mastered once SM-2 has pushed it past three successful
  /// repetitions — the point where its interval starts growing by the easiness
  /// factor rather than by the fixed 1/6-day steps.
  static const masteryRepetitions = 3;

  /// Attempt history is capped: the UI only ever charts the last few weeks, and
  /// an unbounded list in preferences would grow forever.
  static const _maxAttempts = 500;
  static const _maxQuizRuns = 100;

  // ── SRS cards ─────────────────────────────────────────────────────────────
  Map<String, SrsCard> loadCards() {
    final raw = _storage.getJsonMap(StorageKeys.srsCards);
    final cards = <String, SrsCard>{};
    raw.forEach((key, value) {
      final card = SrsCard.tryFromJson(value);
      if (card != null) cards[key] = card;
    });
    return cards;
  }

  Future<void> _saveCards(Map<String, SrsCard> cards) => _storage.setJsonMap(
        StorageKeys.srsCards,
        {for (final e in cards.entries) e.key: e.value.toJson()},
      );

  SrsCard? cardFor(String wordId) => loadCards()[wordId];

  /// Records a review and advances the SM-2 schedule for [wordId].
  Future<SrsCard> review(String wordId, double score) async {
    final cards = loadCards();
    final existing = cards[wordId] ??
        SrsCard(wordId: wordId, nextReviewDate: DateTime.now());
    final updated = SM2Algorithm.update(existing, score);
    cards[wordId] = updated;
    await _saveCards(cards);
    return updated;
  }

  List<SrsCard> dueCards() =>
      loadCards().values.where((c) => c.isDueToday).toList()
        ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));

  // ── Attempts ──────────────────────────────────────────────────────────────
  List<Attempt> loadAttempts() {
    final raw = _storage.getJsonList(StorageKeys.attempts);
    return raw.map(Attempt.tryFromJson).whereType<Attempt>().toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  /// Single entry point for "the learner just practised a word": appends the
  /// attempt, advances SM-2 and marks today as studied.
  Future<SrsCard> recordAttempt({
    required String wordId,
    required double score,
    required AttemptKind kind,
  }) async {
    final attempts = loadAttempts()
      ..add(Attempt(
          wordId: wordId, score: score, at: DateTime.now(), kind: kind));
    final trimmed = attempts.length > _maxAttempts
        ? attempts.sublist(attempts.length - _maxAttempts)
        : attempts;
    await _storage.setJsonList(
        StorageKeys.attempts, trimmed.map((a) => a.toJson()).toList());

    await markStudiedToday();
    return review(wordId, score);
  }

  Future<void> recordQuizRun({required int correct, required int total}) async {
    final runs = loadQuizRuns()
      ..add(QuizRun(at: DateTime.now(), correct: correct, total: total));
    final trimmed = runs.length > _maxQuizRuns
        ? runs.sublist(runs.length - _maxQuizRuns)
        : runs;
    await _storage.setJsonList(
        StorageKeys.quizRuns, trimmed.map((r) => r.toJson()).toList());
    await markStudiedToday();
  }

  List<QuizRun> loadQuizRuns() {
    final raw = _storage.getJsonList(StorageKeys.quizRuns);
    return raw.map(QuizRun.tryFromJson).whereType<QuizRun>().toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  // ── Favourites ────────────────────────────────────────────────────────────
  Set<String> loadFavorites() => _storage.getStringSet(StorageKeys.favorites);

  bool isFavorite(String wordId) => loadFavorites().contains(wordId);

  /// Returns the new state.
  Future<bool> toggleFavorite(String wordId) async {
    final favorites = loadFavorites();
    final added = favorites.add(wordId);
    if (!added) favorites.remove(wordId);
    await _storage.setStringSet(StorageKeys.favorites, favorites);
    return added;
  }

  // ── Study calendar & streak ───────────────────────────────────────────────
  Set<String> loadStudiedDays() =>
      _storage.getStringSet(StorageKeys.studiedDays);

  Future<void> markStudiedToday({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final days = loadStudiedDays()..add(dayKey(today));
    await _storage.setStringSet(StorageKeys.studiedDays, days);
    await _awardFreeze(today);
  }

  // ── Streak freezes ────────────────────────────────────────────────────────
  /// At most this many saved up: enough to survive a bad week, not enough
  /// to stop studying.
  static const maxFreezes = 2;

  /// Premium saves up more, so a trip or a sick week doesn't cost the
  /// streak.
  static const premiumMaxFreezes = 5;

  /// Whether the learner has Premium; set once billing is known.
  bool Function() isPremium = () => false;

  int get freezeCap => isPremium() ? premiumMaxFreezes : maxFreezes;

  int get streakFreezes => _storage.getInt(StorageKeys.streakFreezes) ?? 0;

  /// Days the streak survived thanks to a freeze.
  Set<String> get frozenDays => _storage.getStringSet(StorageKeys.frozenDays);

  /// Every 7 days in a row earns a freeze, once per milestone day.
  Future<void> _awardFreeze(DateTime today) async {
    final streak = currentStreak(now: today);
    if (streak == 0 || streak % 7 != 0) return;
    final awards = _storage.getStringSet(StorageKeys.freezeAwards);
    final key = dayKey(today);
    if (!awards.add(key)) return;
    await _storage.setStringSet(StorageKeys.freezeAwards, awards);
    final freezes = streakFreezes;
    if (freezes < freezeCap) {
      await _storage.setInt(StorageKeys.streakFreezes, freezes + 1);
    }
  }

  /// If yesterday was missed but the day before wasn't, spends a freeze
  /// to fill yesterday in. Returns whether one was used. Call when the app
  /// opens, before showing the streak.
  Future<bool> protectStreak({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final days = loadStudiedDays();
    final yesterday = dayKey(_daysBefore(today, 1));
    if (days.contains(dayKey(today)) || days.contains(yesterday)) return false;
    if (!days.contains(dayKey(_daysBefore(today, 2)))) return false;
    final freezes = streakFreezes;
    if (freezes == 0) return false;
    await _storage.setInt(StorageKeys.streakFreezes, freezes - 1);
    await _storage.setStringSet(StorageKeys.studiedDays, days..add(yesterday));
    await _storage.setStringSet(
        StorageKeys.frozenDays, frozenDays..add(yesterday));
    return true;
  }

  // ── Daily goal ────────────────────────────────────────────────────────────
  int get dailyGoal =>
      _storage.getInt(StorageKeys.dailyGoal) ?? DailyGoals.fallback;

  Future<void> setDailyGoal(int goal) =>
      _storage.setInt(StorageKeys.dailyGoal, goal);

  /// Exercises done per day, by day key. Kept for 90 days.
  Map<String, int> _practiceLog() => {
        for (final e in _storage.getJsonMap(StorageKeys.practiceLog).entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      };

  int practiceOn(DateTime day) => _practiceLog()[dayKey(day)] ?? 0;

  int practiceToday({DateTime? now}) => practiceOn(now ?? DateTime.now());

  bool goalMetToday({DateTime? now}) => practiceToday(now: now) >= dailyGoal;

  /// Days on which the goal (as set today) was reached.
  int goalDaysMet() =>
      _practiceLog().values.where((count) => count >= dailyGoal).length;

  /// Exercises done ever, by kind.
  Map<PracticeKind, int> practiceTotals() {
    final raw = _storage.getJsonMap(StorageKeys.practiceTotals);
    return {
      for (final kind in PracticeKind.values)
        kind: (raw[kind.name] as num?)?.toInt() ?? 0,
    };
  }

  /// The one call every exercise makes when the learner answers: counts
  /// towards today's goal and the totals, and marks today as studied.
  Future<void> recordPractice(PracticeKind kind,
      {int count = 1, DateTime? now}) async {
    if (count <= 0) return;
    final today = now ?? DateTime.now();
    final log = _practiceLog();
    final key = dayKey(today);
    log[key] = (log[key] ?? 0) + count;
    final oldest = dayKey(_daysBefore(today, 90));
    log.removeWhere((day, _) => day.compareTo(oldest) < 0);
    await _storage.setJsonMap(StorageKeys.practiceLog, log);

    final totals = _storage.getJsonMap(StorageKeys.practiceTotals);
    totals[kind.name] = ((totals[kind.name] as num?)?.toInt() ?? 0) + count;
    await _storage.setJsonMap(StorageKeys.practiceTotals, totals);

    await markStudiedToday(now: today);
  }

  bool get studiedToday => loadStudiedDays().contains(dayKey(DateTime.now()));

  /// Consecutive days up to today (or up to yesterday, so the streak is not
  /// reported as broken before the learner has had a chance to practise).
  ///
  /// Steps back by calendar day, never by 24 hours: on the day a clock
  /// changes for daylight saving, "24 hours ago" can skip a date.
  int currentStreak({DateTime? now}) {
    final days = loadStudiedDays();
    if (days.isEmpty) return 0;

    final today = now ?? DateTime.now();
    var offset = days.contains(dayKey(today)) ? 0 : 1;
    if (!days.contains(dayKey(_daysBefore(today, offset)))) return 0;

    var streak = 0;
    while (days.contains(dayKey(_daysBefore(today, offset)))) {
      streak++;
      offset++;
    }
    return streak;
  }

  int longestStreak() {
    final keys = loadStudiedDays().toList()..sort();
    if (keys.isEmpty) return 0;

    // Compared as UTC dates: local midnights around a daylight-saving
    // change are 23 or 25 hours apart, which broke the run.
    DateTime utcDay(String key) {
      final d = DateTime.parse(key);
      return DateTime.utc(d.year, d.month, d.day);
    }

    var best = 1;
    var run = 1;
    for (var i = 1; i < keys.length; i++) {
      final prev = utcDay(keys[i - 1]);
      final curr = utcDay(keys[i]);
      if (curr.difference(prev).inDays == 1) {
        run++;
        best = run > best ? run : best;
      } else {
        run = 1;
      }
    }
    return best;
  }

  // ── Aggregates ────────────────────────────────────────────────────────────
  ProgressStats stats() {
    final cards = loadCards();
    final attempts = loadAttempts();
    final mastered =
        cards.values.where((c) => c.repetitions >= masteryRepetitions).length;
    final average = attempts.isEmpty
        ? 0.0
        : attempts.map((a) => a.score).reduce((a, b) => a + b) /
            attempts.length;

    return ProgressStats(
      wordsSeen: cards.length,
      mastered: mastered,
      dueToday: cards.values.where((c) => c.isDueToday).length,
      totalAttempts: attempts.length,
      averageScore: average,
      currentStreak: currentStreak(),
      longestStreak: longestStreak(),
      favoriteCount: loadFavorites().length,
    );
  }

  /// Practice counts for the last [days] days, oldest first.
  List<({DateTime day, int count})> dailyCounts({int days = 7}) {
    final attempts = loadAttempts();
    final today = DateTime.now();
    return [
      for (var i = days - 1; i >= 0; i--)
        (
          day: _daysBefore(today, i),
          count: attempts
              .where((a) => dayKey(a.at) == dayKey(_daysBefore(today, i)))
              .length,
        ),
    ];
  }

  /// Mean score per day for the last [days] days, skipping days with no
  /// practice so the trend line does not dive to zero on rest days.
  List<({DateTime day, double score})> dailyScores({int days = 14}) {
    final attempts = loadAttempts();
    final today = DateTime.now();
    final out = <({DateTime day, double score})>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = _daysBefore(today, i);
      final ofDay = attempts.where((a) => dayKey(a.at) == dayKey(day)).toList();
      if (ofDay.isEmpty) continue;
      final mean =
          ofDay.map((a) => a.score).reduce((a, b) => a + b) / ofDay.length;
      out.add((day: day, score: mean));
    }
    return out;
  }

  /// Attempt counts grouped by word, strongest first — the input for the
  /// "most practised" ranking.
  Map<String, int> attemptsByWord() {
    final counts = <String, int>{};
    for (final attempt in loadAttempts()) {
      counts[attempt.wordId] = (counts[attempt.wordId] ?? 0) + 1;
    }
    return counts;
  }

  /// Mean score per word, for spotting what still needs work.
  Map<String, double> averageByWord() {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final attempt in loadAttempts()) {
      sums[attempt.wordId] = (sums[attempt.wordId] ?? 0) + attempt.score;
      counts[attempt.wordId] = (counts[attempt.wordId] ?? 0) + 1;
    }
    return {
      for (final id in sums.keys) id: sums[id]! / counts[id]!,
    };
  }

  Future<void> resetAll() => _storage.clearAll();

  /// Midnight [n] calendar days before [date].
  static DateTime _daysBefore(DateTime date, int n) =>
      DateTime(date.year, date.month, date.day - n);

  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
