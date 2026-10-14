import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:french_pass/features/tutor/data/tutor_audio.dart';
import 'package:french_pass/features/tutor/data/tutor_prompt.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';

void main() {
  group('liveEventsFrom', () {
    test('splits server content into audio, transcripts and turn end', () {
      final events = liveEventsFrom(LiveServerContent(
        inputTranscription: const Transcription(text: 'Bonjour'),
        modelTurn: Content.model([
          InlineDataPart(
              'audio/pcm;rate=24000', Uint8List.fromList([1, 0, 2, 0])),
        ]),
        outputTranscription: const Transcription(text: 'Salut !'),
        turnComplete: true,
      ));
      expect(events.map((e) => e.runtimeType), [
        LiveInputTranscript,
        LiveAudio,
        LiveOutputTranscript,
        LiveTurnComplete,
      ]);
      expect((events[1] as LiveAudio).pcm, [1, 0, 2, 0]);
    });

    test('skips empty transcripts and non-audio parts', () {
      final events = liveEventsFrom(LiveServerContent(
        inputTranscription: const Transcription(text: ''),
        modelTurn: Content.model([const TextPart('pensando')]),
        interrupted: true,
      ));
      expect(events.single, isA<LiveInterrupted>());
    });

    test('decodes tool calls with their ids and arguments', () {
      final events = liveEventsFrom(LiveServerToolCall(functionCalls: [
        const FunctionCall(
          'show_correction',
          {'better_fr': 'Je voudrais', 'explanation_es': 'Cortesía'},
          id: 'fc_1',
        ),
      ]));
      final call = (events.single as LiveToolCalls).calls.single;
      expect(call.id, 'fc_1');
      expect(call.args['better_fr'], 'Je voudrais');
    });

    test('a go-away notice warns that the session is ending', () {
      expect(liveEventsFrom(const GoingAwayNotice(timeLeft: '5s')).single,
          isA<LiveGoAway>());
    });
  });

  test('the tutor declares its four on-screen tools', () {
    final json = TutorPrompt.tools().single.toJson();
    final names =
        (json['functionDeclarations'] as List).map((f) => (f as Map)['name']);
    expect(names, [
      'show_correction',
      'show_pronunciation',
      'show_hint',
      'complete_lesson',
    ]);
  });

  group('TutorPrompt', () {
    final lesson = Lessons.byId('cafe')!;

    test('names the role, goal and level', () {
      final text = TutorPrompt.systemInstruction(lesson, LearnerProfile.empty);
      expect(text, contains(lesson.roleFr));
      expect(text, contains(lesson.goalEs));
      expect(text, contains('A1'));
      expect(text, isNot(contains('Lo que sabes de este alumno')));
    });

    test('carries the learner profile into the next lesson', () {
      const profile = LearnerProfile(
        recurringMistakes: ['Confunde le/la'],
        sessions: 3,
      );
      final text = TutorPrompt.systemInstruction(lesson, profile);
      expect(text, contains('Lo que sabes de este alumno'));
      expect(text, contains('Confunde le/la'));
    });

    test('free talk never asks the tutor to close a goal', () {
      final free = Lessons.byId(Lessons.freeTalkId)!;
      expect(TutorPrompt.systemInstruction(free, LearnerProfile.empty),
          contains('conversación libre'));
    });
  });

  test('every lesson id is unique', () {
    final ids = Lessons.all.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  group('joinFragment', () {
    test('joins word pieces and spaced fragments without doubling spaces', () {
      expect(joinFragment('', ' Bonjour'), 'Bonjour');
      expect(joinFragment('Bon', 'jour'), 'Bonjour');
      expect(joinFragment('Bonjour ', ' madame'), 'Bonjour madame');
    });
  });

  test('LearnerProfile.fromJson bounds lists and drops junk', () {
    final profile = LearnerProfile.fromJson({
      'recurringMistakes': [for (var i = 0; i < 20; i++) 'e$i', 3, '  '],
      'sessions': 2,
    });
    expect(profile.recurringMistakes.length, 8);
    expect(profile.sessions, 2);
  });

  test('parseReview reads the model JSON and counts the session', () {
    final body = jsonEncode({
      'summaryEs': 'Bien hecho.',
      'wellDoneEs': ['Saludo', 'Pedido', 'Pago', 'Extra'],
      'practiceNextEs': ['je voudrais'],
      'profile': {
        'levelEstimate': 'A1+',
        'recurringMistakes': ['je veux → je voudrais'],
        'pronunciation': <String>[],
        'strengths': <String>[],
        'personalNotes': <String>[],
      },
    });
    final review =
        TutorReviewService.parseReview(body, const LearnerProfile(sessions: 4));
    expect(review.summaryEs, 'Bien hecho.');
    expect(review.wellDoneEs.length, 3);
    expect(review.profile.levelEstimate, 'A1+');
    expect(review.profile.sessions, 5);
  });

  test('review input includes the notes shown to the learner', () {
    final input = TutorReviewService.buildReviewInput(
      lesson: Lessons.byId('cafe')!,
      transcript: const [
        TutorLine('Bonjour !'),
        LearnerLine('Je veux un café', [
          CorrectionNote(betterFr: 'Je voudrais un café', explanationEs: 'x'),
        ]),
      ],
      previous: LearnerProfile.empty,
      goalReached: true,
    );
    expect(input, contains('ALUMNO: Je veux un café'));
    expect(input, contains('[corrección] Je voudrais un café'));
  });

  group('stripWavHeader', () {
    test('returns raw PCM untouched', () {
      final pcm = Uint8List.fromList([1, 2, 3, 4]);
      expect(TutorReviewService.stripWavHeader(pcm), pcm);
    });

    test('extracts the data chunk of a WAV', () {
      final data = [9, 8, 7, 6];
      final header = BytesBuilder()
        ..add(ascii.encode('RIFF'))
        ..add(_u32(36 + data.length))
        ..add(ascii.encode('WAVEfmt '))
        ..add(_u32(16))
        ..add(List.filled(16, 0))
        ..add(ascii.encode('data'))
        ..add(_u32(data.length))
        ..add(data);
      expect(TutorReviewService.stripWavHeader(header.toBytes()), data);
    });
  });

  test('pcmLevel is 0 for silence and high for a loud signal', () {
    expect(pcmLevel(Uint8List(320)), 0);
    final loud = ByteData(320);
    for (var i = 0; i < 160; i++) {
      loud.setInt16(i * 2, i.isEven ? 20000 : -20000, Endian.little);
    }
    expect(pcmLevel(loud.buffer.asUint8List()), greaterThan(0.9));
  });
}

List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
