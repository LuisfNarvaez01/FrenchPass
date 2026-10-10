import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

class HomeState extends Equatable {
  final Word? word;
  final bool isFavorite;
  final int streak;
  final bool studiedToday;
  final int dueCount;
  final List<Word> dueWords;
  final SrsCard? card;
  final int corpusSize;

  const HomeState({
    this.word,
    this.isFavorite = false,
    this.streak = 0,
    this.studiedToday = false,
    this.dueCount = 0,
    this.dueWords = const [],
    this.card,
    this.corpusSize = 0,
  });

  @override
  List<Object?> get props => [
        word,
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

  HomeCubit(this._words, this._progress) : super(const HomeState());

  /// Recomputes everything the home screen shows. Cheap enough to call on every
  /// return to the tab, which keeps the streak and review count honest.
  void refresh(LevelFilter filter) {
    final word = _words.wordOfTheDay(DateTime.now(), levels: filter.levels);
    final due = _progress.dueCards();

    emit(HomeState(
      word: word,
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

  Future<void> toggleFavorite() async {
    final word = state.word;
    if (word == null) return;
    final isFavorite = await _progress.toggleFavorite(word.id);
    emit(HomeState(
      word: state.word,
      isFavorite: isFavorite,
      streak: state.streak,
      studiedToday: state.studiedToday,
      dueCount: state.dueCount,
      dueWords: state.dueWords,
      card: state.card,
      corpusSize: state.corpusSize,
    ));
  }
}
