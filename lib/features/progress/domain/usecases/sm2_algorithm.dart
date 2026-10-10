import 'package:french_pass/features/progress/domain/entities/srs_card.dart';

/// Implementación del algoritmo SM-2 (SuperMemo 2)
/// Ref: https://www.supermemo.com/en/blog/application-of-a-computer-to-improve-the-results-obtained-in-working-with-the-supermemo-method
class SM2Algorithm {
  SM2Algorithm._();

  static const double _minEasiness = 1.3;
  static const double _maxEasiness = 2.5;

  /// [score] va de 0.0 (completamente mal) a 1.0 (perfecto)
  static SrsCard update(SrsCard card, double score) {
    // Normalizar score a escala 0-5 (SM-2 original)
    final q = (score * 5).round().clamp(0, 5);

    double newEasiness = card.easinessFactor +
        (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    newEasiness = newEasiness.clamp(_minEasiness, _maxEasiness);

    int newRepetitions;
    int newInterval;

    if (q < 3) {
      // Respuesta incorrecta → resetear
      newRepetitions = 0;
      newInterval = 1;
    } else {
      newRepetitions = card.repetitions + 1;
      newInterval = switch (card.repetitions) {
        0 => 1,
        1 => 6,
        _ => (card.intervalDays * newEasiness).round(),
      };
    }

    return card.copyWith(
      repetitions: newRepetitions,
      easinessFactor: newEasiness,
      intervalDays: newInterval,
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      lastReviewDate: DateTime.now(),
      lastScore: score,
    );
  }
}
