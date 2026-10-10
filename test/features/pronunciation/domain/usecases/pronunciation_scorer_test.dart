import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/pronunciation/domain/entities/pronunciation_result.dart';
import 'package:french_pass/features/pronunciation/domain/usecases/pronunciation_scorer.dart';

void main() {
  group('PronunciationScorer', () {
    test('Exact match yields a high score close or equal to 1.0', () {
      final result = PronunciationScorer.score(
        targetWord: 'bonjour',
        recognizedText: 'bonjour',
      );

      expect(result.overallScore, closeTo(1.0, 0.05));
      expect(result.clarityScore, 1.0);
      expect(result.accentScore, 1.0);
      expect(result.isSuccess, isTrue);
    });

    test('Partially matching word yields proportional clarity', () {
      final result = PronunciationScorer.score(
        targetWord: 'croissant',
        recognizedText: 'croisan',
      );

      expect(result.clarityScore, greaterThan(0.5));
      expect(result.overallScore, greaterThan(0.5));
    });

    test('Completely different word yields low score', () {
      final result = PronunciationScorer.score(
        targetWord: 'merci',
        recognizedText: 'ordinateur',
      );

      expect(result.clarityScore, lessThan(0.4));
      expect(result.isSuccess, isFalse);
    });

    test('is case-insensitive and ignores punctuation', () {
      final result = PronunciationScorer.score(
        targetWord: 'Bonjour',
        recognizedText: 'bonjour !',
      );
      expect(result.overallScore, closeTo(1.0, 0.05));
    });

    test('accents in the recognised text are not penalised', () {
      final result = PronunciationScorer.score(
        targetWord: 'café',
        recognizedText: 'cafe',
      );
      expect(result.clarityScore, 1.0);
    });

    test('empty input scores badly rather than throwing', () {
      final result = PronunciationScorer.score(
        targetWord: 'merci',
        recognizedText: '',
      );
      expect(result.overallScore, lessThan(0.3));
      expect(result.isSuccess, isFalse);
    });

    test('scores stay inside 0..1 across a range of inputs', () {
      const pairs = [
        ('eau', 'o'),
        ('maison', 'mezon'),
        ('flâner', 'flaner'),
        ('chef-d\'œuvre', 'chef doeuvre'),
        ('s\'il vous plaît', 'il vous plait'),
        ('x', 'yyyyyyyyyyyy'),
      ];

      for (final (target, heard) in pairs) {
        final r =
            PronunciationScorer.score(targetWord: target, recognizedText: heard);
        for (final score in [
          r.overallScore,
          r.clarityScore,
          r.accentScore,
          r.rhythmScore,
        ]) {
          expect(score, inInclusiveRange(0.0, 1.0),
              reason: '$target vs $heard');
        }
      }
    });

    group('phonetic forgiveness', () {
      // The accent axis exists so that a learner who produces the right sounds
      // is not punished for the spelling the recognizer happened to emit.
      test('"eau" and "o" are treated as the same sound', () {
        final result = PronunciationScorer.score(
          targetWord: 'eau',
          recognizedText: 'o',
        );
        expect(result.accentScore, 1.0,
            reason: 'the "eau" trigraph must be applied before "au"/"eu"');
      });

      test('silent final consonants do not cost accent points', () {
        final result = PronunciationScorer.score(
          targetWord: 'pain',
          recognizedText: 'pains',
        );
        expect(result.accentScore, 1.0);
      });

      test('"ph" heard as "f" keeps the accent score perfect', () {
        final result = PronunciationScorer.score(
          targetWord: 'téléphone',
          recognizedText: 'telefone',
        );
        expect(result.accentScore, 1.0);
      });

      test('"qu" heard as "k" keeps the accent score perfect', () {
        final result = PronunciationScorer.score(
          targetWord: 'quartier',
          recognizedText: 'kartier',
        );
        expect(result.accentScore, 1.0);
      });

      test('the accent axis is at least as forgiving as raw spelling', () {
        const pairs = [
          ('eau', 'o'),
          ('téléphone', 'telefone'),
          ('chat', 'sha'),
        ];
        for (final (target, heard) in pairs) {
          final r = PronunciationScorer.score(
              targetWord: target, recognizedText: heard);
          expect(r.accentScore, greaterThanOrEqualTo(r.clarityScore),
              reason: '$target vs $heard');
        }
      });
    });

    group('feedback bands', () {
      test('a perfect attempt reads as Parfait', () {
        final result = PronunciationScorer.score(
          targetWord: 'merci',
          recognizedText: 'merci',
        );
        expect(result.feedback.labelEs, contains('Parfait'));
      });

      test('a hopeless attempt reads as Réessaie', () {
        final result = PronunciationScorer.score(
          targetWord: 'bonjour',
          recognizedText: 'zzzz',
        );
        expect(result.feedback.labelEs, contains('Réessaie'));
      });
    });
  });
}
