import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/progress/domain/usecases/sm2_algorithm.dart';

void main() {
  group('SM2Algorithm Tests', () {
    test('Initial card on first correct response (score 1.0) sets interval to 1 and repetitions to 1', () {
      final initial = SrsCard(
        wordId: 'word_1',
        repetitions: 0,
        intervalDays: 1,
        easinessFactor: 2.5,
        nextReviewDate: DateTime.now(),
      );

      final updated = SM2Algorithm.update(initial, 1.0);

      expect(updated.repetitions, 1);
      expect(updated.intervalDays, 1);
      expect(updated.easinessFactor, greaterThanOrEqualTo(2.5));
    });

    test('Second correct response (score 0.8) sets interval to 6 and repetitions to 2', () {
      final firstReview = SrsCard(
        wordId: 'word_1',
        repetitions: 1,
        intervalDays: 1,
        easinessFactor: 2.5,
        nextReviewDate: DateTime.now(),
      );

      final updated = SM2Algorithm.update(firstReview, 0.8);

      expect(updated.repetitions, 2);
      expect(updated.intervalDays, 6);
      expect(updated.easinessFactor, 2.5);
    });

    test('Failed recall (score 0.2) resets repetitions to 0 and interval to 1', () {
      final matureCard = SrsCard(
        wordId: 'word_1',
        repetitions: 5,
        intervalDays: 30,
        easinessFactor: 2.5,
        nextReviewDate: DateTime.now(),
      );

      final updated = SM2Algorithm.update(matureCard, 0.2);

      expect(updated.repetitions, 0);
      expect(updated.intervalDays, 1);
      expect(updated.easinessFactor, greaterThanOrEqualTo(1.3));
    });
  });
}
