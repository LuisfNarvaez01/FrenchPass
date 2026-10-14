import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:french_pass/features/tutor/data/tutor_audio.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';
import 'package:french_pass/features/tutor/presentation/cubit/tutor_session_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late FakeLiveClient client;
  late FakeAudio audio;
  late FakeReviewer reviewer;
  late TutorRepository repo;

  Future<TutorSessionCubit> started({bool aiReady = true}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    repo = TutorRepository(storage);
    AiBackend.readyForTesting = aiReady;
    final cubit = TutorSessionCubit(
      lesson: Lessons.byId('cafe')!,
      repository: repo,
      reviewer: reviewer,
      audio: audio,
      client: client,
    );
    await cubit.start();
    return cubit;
  }

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  setUp(() {
    client = FakeLiveClient();
    audio = FakeAudio();
    reviewer = FakeReviewer();
  });

  test('without the AI backend it explains why and never connects', () async {
    final cubit = await started(aiReady: false);
    expect(cubit.state.phase, TutorPhase.error);
    expect(cubit.state.error, contains('no está disponible'));
    expect(client.connected, isFalse);
    await cubit.close();
  });

  test('opens the scene: connects, starts the mic and asks for a greeting',
      () async {
    final cubit = await started();
    expect(client.connected, isTrue);
    expect(audio.micOn, isTrue);
    expect(client.texts.single, contains('Empieza la escena'));
    expect(cubit.state.phase, TutorPhase.thinking);
    await cubit.close();
  });

  test('the mic is gated while the tutor speaks and reopens after', () async {
    final cubit = await started();
    client.emit(LiveAudio(Uint8List(480)));
    client.emit(const LiveOutputTranscript('Bonjour !'));
    await pump();
    expect(cubit.state.phase, TutorPhase.tutorSpeaking);

    audio.chunk(); // Mic picks up the speaker...
    expect(client.audioSent, 0, reason: '...but nothing is sent');

    client.emit(const LiveTurnComplete());
    await pump();
    audio.finishPlayback();
    await pump();
    expect(cubit.state.phase, TutorPhase.listening);
    audio.chunk();
    expect(client.audioSent, 1);
    await cubit.close();
  });

  test('corrections attach to what the learner just said', () async {
    final cubit = await started();
    client.emit(const LiveOutputTranscript('Bonjour !'));
    client.emit(const LiveInputTranscript('Je veux'));
    client.emit(const LiveInputTranscript(' un café'));
    client.emit(const LiveToolCalls([
      LiveToolCall('1', 'show_correction', {
        'better_fr': 'Je voudrais un café',
        'explanation_es': 'Más educado',
      }),
    ]));
    await pump();

    final learner = cubit.state.messages.whereType<LearnerLine>().single;
    expect(learner.text, 'Je veux un café');
    expect((learner.notes.single as CorrectionNote).betterFr,
        'Je voudrais un café');
    expect(client.toolResponses, ['1'], reason: 'every call is answered');
    await cubit.close();
  });

  test('help asks the tutor and shows the hint on a fresh learner line',
      () async {
    final cubit = await started();
    client.emit(const LiveTurnComplete());
    await pump();
    expect(cubit.state.phase, TutorPhase.listening);

    cubit.askForHelp();
    expect(client.texts.last, contains('No sé cómo decirlo'));
    client.emit(const LiveToolCalls([
      LiveToolCall('2', 'show_hint', {
        'phrase_fr': 'Un café, s’il vous plaît',
        'translation_es': 'Un café, por favor',
      }),
    ]));
    client.emit(const LiveInputTranscript('Un café'));
    await pump();

    final line = cubit.state.messages.last as LearnerLine;
    expect(line.notes.single, isA<HintNote>());
    expect(line.text, 'Un café', reason: 'the attempt continues that line');
    await cubit.close();
  });

  test('a completed goal ends and reviews once the goodbye has played',
      () async {
    final cubit = await started();
    client.emit(const LiveInputTranscript('L’addition, s’il vous plaît'));
    client.emit(const LiveToolCalls([
      LiveToolCall('3', 'complete_lesson', {'reason_es': 'Pagó'})
    ]));
    client.emit(LiveAudio(Uint8List(480)));
    client.emit(const LiveTurnComplete());
    await pump();
    expect(cubit.state.phase, TutorPhase.tutorSpeaking);

    audio.finishPlayback();
    await pump();
    await pump();
    expect(cubit.state.phase, TutorPhase.ended);
    expect(cubit.state.goalReached, isTrue);
    expect(cubit.state.review?.summaryEs, 'Resumen');
    expect(repo.profile().sessions, 1, reason: 'profile was saved');
    expect(repo.completedLessonIds(), contains('cafe'));
    await cubit.close();
  });

  test('interrupting drops the rest of the tutor turn', () async {
    final cubit = await started();
    client.emit(LiveAudio(Uint8List(480)));
    await pump();
    await cubit.interrupt();
    expect(cubit.state.phase, TutorPhase.listening);
    expect(audio.stopped, isTrue);

    client.emit(LiveAudio(Uint8List(480)));
    await pump();
    expect(audio.played, 1, reason: 'late audio of the cut turn is dropped');
    expect(cubit.state.phase, TutorPhase.listening);
    await cubit.close();
  });

  test('a review failure still records the lesson', () async {
    reviewer.fail = true;
    final cubit = await started();
    client.emit(const LiveInputTranscript('Bonjour'));
    await pump();
    await cubit.endLesson();
    expect(cubit.state.reviewFailed, isTrue);
    expect(repo.history().single.lessonId, 'cafe');
    await cubit.close();
  });

  test('ending before saying anything skips the review', () async {
    final cubit = await started();
    await cubit.endLesson();
    expect(cubit.state.phase, TutorPhase.ended);
    expect(reviewer.calls, 0);
    expect(repo.history(), isEmpty);
    await cubit.close();
  });
}

class FakeLiveClient implements GeminiLiveClient {
  final _events = StreamController<LiveEvent>.broadcast(sync: true);
  bool connected = false;
  int audioSent = 0;
  final texts = <String>[];
  final toolResponses = <String>[];

  void emit(LiveEvent e) => _events.add(e);

  @override
  Stream<LiveEvent> get events => _events.stream;
  @override
  bool get isOpen => connected;
  @override
  Future<void> connect({
    required String model,
    required String voice,
    required String systemInstruction,
    required List<Tool> tools,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    connected = true;
  }

  @override
  void sendAudio(Uint8List pcm16k) => audioSent++;
  @override
  void sendText(String text) => texts.add(text);
  @override
  void sendToolResponses(List<LiveToolCall> calls) =>
      toolResponses.addAll(calls.map((c) => c.id));
  @override
  Future<void> close() async => connected = false;
  @override
  Future<void> dispose() async {}
}

class FakeAudio implements TutorAudio {
  void Function(Uint8List)? _onChunk;
  bool micOn = false;
  bool _playing = false;
  bool stopped = false;
  int played = 0;
  final _drained = StreamController<void>.broadcast(sync: true);

  void chunk() => _onChunk?.call(Uint8List(320));
  void finishPlayback() {
    _playing = false;
    _drained.add(null);
  }

  @override
  Future<bool> requestMicrophone() async => true;
  @override
  Future<void> startMic(
      {required void Function(Uint8List pcm) onChunk,
      void Function(double level)? onLevel}) async {
    _onChunk = onChunk;
    micOn = true;
  }

  @override
  Future<void> stopMic() async => micOn = false;
  @override
  Future<void> play(Uint8List pcm) async {
    played++;
    _playing = true;
  }

  @override
  Future<void> stopPlayback() async {
    stopped = true;
    _playing = false;
  }

  @override
  Stream<void> get playbackDrained => _drained.stream;
  @override
  bool get isPlaying => _playing;
  @override
  Future<void> dispose() async {}
}

class FakeReviewer implements TutorReviewService {
  bool fail = false;
  int calls = 0;

  @override
  Future<LessonReview> review({
    required Lesson lesson,
    required List<TutorMessage> transcript,
    required LearnerProfile previous,
    required bool goalReached,
  }) async {
    calls++;
    if (fail) throw const AiException(detail: 'boom');
    return LessonReview(
      summaryEs: 'Resumen',
      wellDoneEs: const [],
      practiceNextEs: const [],
      profile: previous.copyWith(sessions: previous.sessions + 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
