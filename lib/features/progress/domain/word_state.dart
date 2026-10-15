import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';

/// Where a word stands for this learner, from its spaced-repetition card.
enum WordState {
  /// Never practised.
  fresh('Sin empezar'),

  /// Practised, not yet due again.
  learning('Aprendiendo'),

  /// Spaced repetition is bringing it back today.
  due('Por repasar'),

  /// Past [ProgressRepository.masteryRepetitions] successful reviews.
  mastered('Dominada');

  final String labelEs;
  const WordState(this.labelEs);

  static WordState of(SrsCard? card) {
    if (card == null) return WordState.fresh;
    if (card.isDueToday) return WordState.due;
    if (card.repetitions >= ProgressRepository.masteryRepetitions) {
      return WordState.mastered;
    }
    return WordState.learning;
  }
}
