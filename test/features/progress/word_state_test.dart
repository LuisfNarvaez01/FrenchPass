import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/progress/domain/word_state.dart';

void main() {
  final now = DateTime.now();
  SrsCard card({required int reps, required DateTime next}) => SrsCard(
        wordId: 'w',
        repetitions: reps,
        easinessFactor: 2.5,
        intervalDays: 1,
        nextReviewDate: next,
      );

  test('a word moves from fresh to learning, due and mastered', () {
    expect(WordState.of(null), WordState.fresh);
    expect(WordState.of(card(reps: 1, next: now.add(const Duration(days: 3)))),
        WordState.learning);
    expect(
        WordState.of(
            card(reps: 1, next: now.subtract(const Duration(days: 1)))),
        WordState.due);
    expect(WordState.of(card(reps: 4, next: now.add(const Duration(days: 20)))),
        WordState.mastered);
  });
}
