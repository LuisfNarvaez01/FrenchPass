import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';

void main() {
  group('SavedSession JSON', () {
    test('round-trips messages, notes and cached studies', () {
      final session = SavedSession(
        id: '1',
        lessonId: 'cafe',
        date: DateTime(2026, 10, 12, 9, 30),
        goalReached: true,
        summaryEs: 'Muy bien.',
        messages: const [
          TutorLine('Bonjour, vous désirez ?'),
          LearnerLine('Je veux un café', [
            CorrectionNote(
              originalFr: 'Je veux',
              betterFr: 'Je voudrais',
              explanationEs: 'Más cortés',
            ),
            PronunciationNote(wordFr: 'café', tipEs: 'é cerrada'),
          ]),
          LearnerLine('', [
            HintNote(phraseFr: "L'addition", translationEs: 'La cuenta'),
          ]),
        ],
        studies: const {
          0: LineStudy(
            translationEs: 'Hola, ¿qué desea?',
            words: [WordGloss(word: 'Bonjour', ipa: 'bɔ̃ʒuʁ')],
            replies: [ReplyOption(level: 'A1', fr: 'Un café', es: 'Un café')],
          ),
        },
      );

      final restored = SavedSession.fromJson(
          jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>);

      expect(restored.id, '1');
      expect(restored.date, session.date);
      expect(restored.goalReached, isTrue);
      expect(restored.messages, hasLength(3));
      expect(restored.messages[0], isA<TutorLine>());
      final learner = restored.messages[1] as LearnerLine;
      expect(learner.text, 'Je veux un café');
      expect((learner.notes[0] as CorrectionNote).betterFr, 'Je voudrais');
      expect((learner.notes[1] as PronunciationNote).wordFr, 'café');
      expect((restored.messages[2] as LearnerLine).notes.single, isA<HintNote>());
      expect(restored.studies[0]!.replies.single.fr, 'Un café');
      expect(restored.spokenLines, 2);
    });

    test('skips unknown entries instead of failing', () {
      final restored = SavedSession.fromJson({
        'id': 'x',
        'messages': [
          {'who': 'robot', 'text': '?'},
          {'who': 'tutor', 'text': 'Salut'},
          'garbage',
        ],
        'studies': {'nope': <String, dynamic>{}, '0': {'translationEs': 'Hola'}},
      });
      expect(restored.messages, hasLength(1));
      expect(restored.studies.keys, [0]);
    });
  });

  group('LineStudy.glossFor', () {
    const study = LineStudy(translationEs: '', words: [
      WordGloss(word: 'eau', meaningEs: 'agua'),
      WordGloss(word: 'Vous', meaningEs: 'usted'),
    ]);

    test('matches ignoring case and punctuation', () {
      expect(study.glossFor('vous,')?.meaningEs, 'usted');
    });

    test('matches an elided token to its bare word', () {
      expect(study.glossFor("l'eau ?")?.meaningEs, 'agua');
      expect(study.glossFor('l’eau')?.meaningEs, 'agua');
    });

    test('returns null for an unknown word', () {
      expect(study.glossFor('chat'), isNull);
    });
  });

  group('TutorReviewService.parseStudy', () {
    String wrap(Map<String, dynamic> payload) => jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': jsonEncode(payload)},
                ],
              },
            },
          ],
        });

    final payload = {
      'translationEs': 'Hola',
      'words': [
        {'word': 'Bonjour', 'ipa': 'bɔ̃ʒuʁ', 'meaningEs': 'hola', 'noteEs': ''},
      ],
      'replies': [
        {'level': 'A1', 'fr': 'Bonjour', 'es': 'Hola'},
        {'level': 'A2', 'fr': 'Bonjour madame', 'es': 'Hola señora'},
      ],
      'betterFr': 'Bonjour !',
      'betterNoteEs': 'nada',
    };

    test('keeps replies only for tutor lines', () {
      final s = TutorReviewService.parseStudy(wrap(payload), byTutor: true);
      expect(s.replies, hasLength(2));
      expect(s.betterFr, isEmpty);
      expect(s.words.single.ipa, 'bɔ̃ʒuʁ');
    });

    test('keeps the natural rewrite only for learner lines', () {
      final s = TutorReviewService.parseStudy(wrap(payload), byTutor: false);
      expect(s.replies, isEmpty);
      expect(s.betterFr, 'Bonjour !');
    });
  });
}
