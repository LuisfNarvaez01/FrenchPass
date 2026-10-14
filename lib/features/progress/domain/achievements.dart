import 'package:flutter/material.dart';

import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

/// What the achievements are measured against.
class AchievementStats {
  final int longestStreak;
  final int wordsSeen;
  final int mastered;
  final int goalDays;
  final int tutorLessons;
  final Map<PracticeKind, int> totals;

  const AchievementStats({
    required this.longestStreak,
    required this.wordsSeen,
    required this.mastered,
    required this.goalDays,
    required this.tutorLessons,
    required this.totals,
  });

  int of(PracticeKind kind) => totals[kind] ?? 0;
  int get practiceEver => totals.values.fold(0, (a, b) => a + b);
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Progress towards it, 0 to 1.
  final double Function(AchievementStats s) progress;

  const Achievement(
      this.id, this.title, this.description, this.icon, this.progress);

  bool reachedBy(AchievementStats s) => progress(s) >= 1;
}

double _ratio(int value, int target) => (value / target).clamp(0, 1).toDouble();

abstract final class Achievements {
  static final all = <Achievement>[
    Achievement('first-step', 'Primer paso', 'Haz tu primer ejercicio.',
        Icons.flag_rounded, (s) => _ratio(s.practiceEver, 1)),
    Achievement('streak-3', 'Tres al hilo', 'Estudia 3 días seguidos.',
        Icons.local_fire_department_rounded, (s) => _ratio(s.longestStreak, 3)),
    Achievement('streak-7', 'Una semana entera', 'Estudia 7 días seguidos.',
        Icons.local_fire_department_rounded, (s) => _ratio(s.longestStreak, 7)),
    Achievement('streak-30', 'Un mes sin parar', 'Estudia 30 días seguidos.',
        Icons.whatshot_rounded, (s) => _ratio(s.longestStreak, 30)),
    Achievement('streak-100', 'Cien días', 'Estudia 100 días seguidos.',
        Icons.emoji_events_rounded, (s) => _ratio(s.longestStreak, 100)),
    Achievement('goal-7', 'Meta cumplida', 'Cumple tu meta diaria 7 días.',
        Icons.track_changes_rounded, (s) => _ratio(s.goalDays, 7)),
    Achievement('goal-30', 'Disciplina', 'Cumple tu meta diaria 30 días.',
        Icons.military_tech_rounded, (s) => _ratio(s.goalDays, 30)),
    Achievement('words-50', 'Cincuenta palabras', 'Practica 50 palabras.',
        Icons.style_rounded, (s) => _ratio(s.wordsSeen, 50)),
    Achievement('words-200', 'Doscientas palabras', 'Practica 200 palabras.',
        Icons.library_books_rounded, (s) => _ratio(s.wordsSeen, 200)),
    Achievement('words-500', 'Vocabulario de viaje', 'Practica 500 palabras.',
        Icons.public_rounded, (s) => _ratio(s.wordsSeen, 500)),
    Achievement('mastered-25', 'Ya son tuyas', 'Domina 25 palabras.',
        Icons.verified_rounded, (s) => _ratio(s.mastered, 25)),
    Achievement('mastered-100', 'Memoria de elefante', 'Domina 100 palabras.',
        Icons.psychology_rounded, (s) => _ratio(s.mastered, 100)),
    Achievement(
        'conjugation-100',
        'Verbo a verbo',
        'Conjuga 100 formas correctamente.',
        Icons.edit_note_rounded,
        (s) => _ratio(s.of(PracticeKind.conjugation), 100)),
    Achievement('dictation-50', 'Buen oído', 'Acierta 50 dictados.',
        Icons.hearing_rounded, (s) => _ratio(s.of(PracticeKind.dictation), 50)),
    Achievement('numbers-50', 'Cuentas claras', 'Acierta 50 números u horas.',
        Icons.pin_rounded, (s) => _ratio(s.of(PracticeKind.numbers), 50)),
    Achievement(
        'false-friends-30',
        'No me engañan',
        'Acierta 30 falsos amigos.',
        Icons.masks_rounded,
        (s) => _ratio(s.of(PracticeKind.falseFriends), 30)),
    Achievement('reader-5', 'Lector', 'Termina 5 lecturas.',
        Icons.menu_book_rounded, (s) => _ratio(s.of(PracticeKind.reading), 5)),
    Achievement(
        'grammar-35',
        'Gramático',
        'Acierta 35 ejercicios de gramática.',
        Icons.rule_rounded,
        (s) => _ratio(s.of(PracticeKind.grammar), 35)),
    Achievement(
        'tutor-1',
        'Primera conversación',
        'Termina una lección con el tutor.',
        Icons.record_voice_over_rounded,
        (s) => _ratio(s.tutorLessons, 1)),
    Achievement('tutor-10', 'Conversador', 'Termina 10 lecciones con el tutor.',
        Icons.forum_rounded, (s) => _ratio(s.tutorLessons, 10)),
  ];
}

/// Tracks which achievements are unlocked and which the learner hasn't
/// seen yet, so each one is celebrated once.
class AchievementService {
  final StorageService _storage;
  final ProgressRepository _progress;
  final int Function() _tutorLessons;

  AchievementService(this._storage, this._progress,
      {required int Function() tutorLessons})
      : _tutorLessons = tutorLessons;

  AchievementStats stats() {
    final s = _progress.stats();
    return AchievementStats(
      longestStreak: s.longestStreak,
      wordsSeen: s.wordsSeen,
      mastered: s.mastered,
      goalDays: _progress.goalDaysMet(),
      tutorLessons: _tutorLessons(),
      totals: _progress.practiceTotals(),
    );
  }

  /// Unlock dates by id.
  Map<String, DateTime> unlocked() => {
        for (final e in _storage.getJsonMap(StorageKeys.achievements).entries)
          if (DateTime.tryParse('${e.value}') case final date?) e.key: date,
      };

  /// Unlocks whatever has been reached and returns the newly unlocked.
  Future<List<Achievement>> refresh({DateTime? now}) async {
    final stats = this.stats();
    final done = _storage.getJsonMap(StorageKeys.achievements);
    final fresh = [
      for (final a in Achievements.all)
        if (!done.containsKey(a.id) && a.reachedBy(stats)) a,
    ];
    if (fresh.isEmpty) return const [];
    final at = (now ?? DateTime.now()).toIso8601String();
    for (final a in fresh) {
      done[a.id] = at;
    }
    await _storage.setJsonMap(StorageKeys.achievements, done);
    return fresh;
  }

  /// Unlocked but not shown to the learner yet.
  List<Achievement> unseen() {
    final seen = _storage.getStringSet(StorageKeys.achievementsSeen);
    final got = unlocked();
    return [
      for (final a in Achievements.all)
        if (got.containsKey(a.id) && !seen.contains(a.id)) a,
    ];
  }

  Future<void> markAllSeen() => _storage.setStringSet(
      StorageKeys.achievementsSeen, unlocked().keys.toSet());
}
