// Talks to the real Gemini Live API. Skipped unless GEMINI_API_KEY is set:
//
//   GEMINI_API_KEY=... flutter test test/features/tutor/live_smoke_test.dart
//
// Optionally GEMINI_TEST_WAV points at a 16-bit mono WAV of a learner line
// (any sample rate) to check transcription and correction tool calls.
@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:french_pass/features/tutor/data/tutor_prompt.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';

void main() {
  final key = Platform.environment['GEMINI_API_KEY'];

  test('opens a cafe lesson, hears the greeting and a corrected reply',
      () async {
    final client = GeminiLiveClient();
    final events = <LiveEvent>[];
    final sub = client.events.listen(events.add);

    final lesson = Lessons.byId('cafe')!;
    final sw = Stopwatch()..start();
    await client.connect(
      apiKey: key!,
      setup: buildLiveSetup(
        model: GeminiModels.live,
        voice: 'Kore',
        systemInstruction:
            TutorPrompt.systemInstruction(lesson, LearnerProfile.empty),
        tools: TutorPrompt.tools(),
      ),
    );
    // ignore: avoid_print
    print('connected in ${sw.elapsedMilliseconds} ms');

    sw.reset();
    client.sendText(TutorPrompt.startRequest);
    await _waitFor(events, (e) => e is LiveTurnComplete);
    final firstAudio = events.whereType<LiveAudio>();
    expect(firstAudio, isNotEmpty, reason: 'the tutor should speak first');
    final greeting =
        events.whereType<LiveOutputTranscript>().map((e) => e.text).join();
    // ignore: avoid_print
    print('greeting (${sw.elapsedMilliseconds} ms): $greeting');

    final wavPath = Platform.environment['GEMINI_TEST_WAV'];
    if (wavPath != null) {
      events.clear();
      final pcm = _wavTo16k(File(wavPath).readAsBytesSync());
      for (var i = 0; i < pcm.length; i += 3200) {
        client.sendAudio(
            Uint8List.sublistView(pcm, i, (i + 3200).clamp(0, pcm.length)));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final silence = Uint8List(3200);
      final pad = Timer.periodic(
          const Duration(milliseconds: 100), (_) => client.sendAudio(silence));
      await _waitFor(
        events,
        (e) => e is LiveTurnComplete,
        after: (all) => all.any((e) => e is LiveAudio),
        onTools: client.sendToolResponses,
      );
      pad.cancel();
      final heard =
          events.whereType<LiveInputTranscript>().map((e) => e.text).join();
      final reply =
          events.whereType<LiveOutputTranscript>().map((e) => e.text).join();
      final tools = events
          .whereType<LiveToolCalls>()
          .expand((e) => e.calls)
          .map((c) => '${c.name} ${c.args}');
      // ignore: avoid_print
      print('heard: $heard\nreply: $reply\ntools: ${tools.join('\n')}');
      expect(heard, isNotEmpty);
    }

    await sub.cancel();
    await client.dispose();
  },
      skip: key == null ? 'GEMINI_API_KEY not set' : false,
      timeout: const Timeout(Duration(seconds: 90)));

  test('reviews a lesson, translates a line and previews a voice', () async {
    final service = TutorReviewService();
    final sw = Stopwatch()..start();
    final review = await service.review(
      apiKey: key!,
      lesson: Lessons.byId('cafe')!,
      transcript: const [
        TutorLine('Bonjour ! Qu’est-ce que je vous sers ?'),
        LearnerLine('Je veux un café, s’il vous plaît.', [
          CorrectionNote(
            betterFr: 'Je voudrais un café, s’il vous plaît.',
            explanationEs: '"Je voudrais" es más educado.',
          ),
        ]),
        TutorLine('Très bien. Avec un croissant ?'),
        LearnerLine('Oui, et l’addition. Je suis ingénieur, je suis pressé.'),
      ],
      previous: LearnerProfile.empty,
      goalReached: true,
    );
    // ignore: avoid_print
    print('review ${sw.elapsedMilliseconds} ms: ${review.summaryEs} | '
        'mistakes: ${review.profile.recurringMistakes} | '
        'notes: ${review.profile.personalNotes}');
    expect(review.summaryEs, isNotEmpty);
    expect(review.profile.sessions, 1);

    final es = await service.translate(
        apiKey: key, french: 'Avec du sucre et du lait ?');
    // ignore: avoid_print
    print('translation: $es');
    expect(es.toLowerCase(), contains('azúcar'));

    final pcm =
        await service.synthesize(apiKey: key, voice: 'Kore', text: 'Bonjour !');
    expect(pcm.length, greaterThan(4800), reason: 'at least 0.1 s of audio');
    expect(await service.validateKey(key), isTrue);
    expect(await service.validateKey('nope'), isFalse);
  },
      skip: key == null ? 'GEMINI_API_KEY not set' : false,
      timeout: const Timeout(Duration(seconds: 90)));
}

Future<void> _waitFor(
  List<LiveEvent> events,
  bool Function(LiveEvent) done, {
  bool Function(List<LiveEvent>)? after,
  void Function(List<LiveToolCall>)? onTools,
}) async {
  var answered = 0;
  for (var i = 0; i < 600; i++) {
    final tools = events.whereType<LiveToolCalls>().toList();
    if (onTools != null) {
      for (final t in tools.skip(answered)) {
        onTools(t.calls);
      }
      answered = tools.length;
    }
    if (events.whereType<LiveClosed>().isNotEmpty) {
      fail('closed: ${events.whereType<LiveClosed>().first.reason}');
    }
    if (events.any(done) && (after == null || after(events))) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('timed out');
}

/// Reads a PCM16 mono WAV and resamples it (nearest) to 16 kHz.
Uint8List _wavTo16k(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  final rate = view.getUint32(24, Endian.little);
  var offset = 12;
  while (String.fromCharCodes(wav.sublist(offset, offset + 4)) != 'data') {
    offset += 8 + view.getUint32(offset + 4, Endian.little);
  }
  final data = Uint8List.sublistView(wav, offset + 8);
  final input = data.buffer.asByteData(data.offsetInBytes, data.length);
  final inSamples = data.length ~/ 2;
  final outSamples = inSamples * 16000 ~/ rate;
  final out = ByteData(outSamples * 2);
  for (var i = 0; i < outSamples; i++) {
    final j = (i * rate ~/ 16000).clamp(0, inSamples - 1);
    out.setInt16(i * 2, input.getInt16(j * 2, Endian.little), Endian.little);
  }
  return out.buffer.asUint8List();
}
