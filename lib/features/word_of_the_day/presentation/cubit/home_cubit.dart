import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

class HomeState extends Equatable {
  final Word? word;

  /// True once the learner has tapped "Otra palabra" — the card is showing a
  /// random pick rather than today's official word, and the "volver a hoy"
  /// affordance should be visible.
  final bool isExploring;
  final bool isFavorite;
  final int streak;
  final bool studiedToday;
  final int dueCount;
  final List<Word> dueWords;
  final SrsCard? card;
  final int corpusSize;

  const HomeState({
    this.word,
    this.isExploring = false,
    this.isFavorite = false,
    this.streak = 0,
    this.studiedToday = false,
    this.dueCount = 0,
    this.dueWords = const [],
    this.card,
    this.corpusSize = 0,
  });

  HomeState copyWith({
    Word? word,
    bool? isExploring,
    bool? isFavorite,
    int? streak,
    bool? studiedToday,
    int? dueCount,
    List<Word>? dueWords,
    SrsCard? card,
    bool clearCard = false,
    int? corpusSize,
  }) =>
      HomeState(
        word: word ?? this.word,
        isExploring: isExploring ?? this.isExploring,
        isFavorite: isFavorite ?? this.isFavorite,
        streak: streak ?? this.streak,
        studiedToday: studiedToday ?? this.studiedToday,
        dueCount: dueCount ?? this.dueCount,
        dueWords: dueWords ?? this.dueWords,
        card: clearCard ? null : (card ?? this.card),
        corpusSize: corpusSize ?? this.corpusSize,
      );

  @override
  List<Object?> get props => [
        word,
        isExploring,
        isFavorite,
        streak,
        studiedToday,
        dueCount,
        dueWords,
        card,
        corpusSize,
      ];
}

class HomeCubit extends Cubit<HomeState> {
  final WordRepository _words;
  final ProgressRepository _progress;
  final Random _random = Random();

  HomeCubit(this._words, this._progress) : super(const HomeState());

  /// Recomputes everything the home screen shows, and resets to today's
  /// official word. Cheap enough to call on every return to the tab, which
  /// keeps the streak and review count honest.
  void refresh(LevelFilter filter) {
    final word = _words.wordOfTheDay(DateTime.now(), levels: filter.levels);
    final due = _progress.dueCards();

    emit(HomeState(
      word: word,
      isExploring: false,
      isFavorite: word != null && _progress.isFavorite(word.id),
      streak: _progress.currentStreak(),
      studiedToday: _progress.studiedToday,
      dueCount: due.length,
      dueWords: due
          .map((c) => _words.byId(c.wordId))
          .whereType<Word>()
          .take(8)
          .toList(),
      card: word == null ? null : _progress.cardFor(word.id),
      corpusSize: _words.all.length,
    ));
  }

  /// Swaps the card for a different random word from the same level pool —
  /// "ya aprendí esta, dame otra" without waiting for tomorrow. Streak, due
  /// count and the daily word itself are untouched; only the displayed word
  /// and its favourite/SRS summary change.
  void showRandomWord(LevelFilter filter) {
    final pool = _words.pool(levels: filter.levels);
    if (pool.isEmpty) return;

    final current = state.word?.id;
    Word next = pool[_random.nextInt(pool.length)];
    if (pool.length > 1) {
      // Avoid landing on the same word twice in a row.
      var attempts = 0;
      while (next.id == current && attempts < 5) {
        next = pool[_random.nextInt(pool.length)];
        attempts++;
      }
    }

    emit(state.copyWith(
      word: next,
      isExploring: true,
      isFavorite: _progress.isFavorite(next.id),
      card: _progress.cardFor(next.id),
      clearCard: _progress.cardFor(next.id) == null,
    ));
  }

  Future<void> toggleFavorite() async {
    final word = state.word;
    if (word == null) return;
    final isFavorite = await _progress.toggleFavorite(word.id);
    emit(state.copyWith(isFavorite: isFavorite));
  }

  /// Call after a practice session on the currently displayed word, when that
  /// word is an explored pick rather than today's word: it refreshes the SRS
  /// summary, the streak and the due count without discarding the explored
  /// word the way a full [refresh] would.
  void refreshCurrentCard() {
    final word = state.word;
    if (word == null) return;
    final due = _progress.dueCards();
    emit(state.copyWith(
      card: _progress.cardFor(word.id),
      clearCard: _progress.cardFor(word.id) == null,
      streak: _progress.currentStreak(),
      studiedToday: _progress.studiedToday,
      dueCount: due.length,
      dueWords:
          due.map((c) => _words.byId(c.wordId)).whereType<Word>().take(8).toList(),
    ));
  }
}
