import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import 'package:french_pass/core/ai/ai_backend.dart';

/// Model ids in one place: preview names change, and swapping one should be
/// a one-line edit.
abstract final class GeminiModels {
  /// Speech-to-speech. Measured at ~0.7 s to first audio.
  static const live = 'gemini-3.1-flash-live-preview';

  /// Fallback if the preview above is withdrawn or rejects the setup.
  static const liveFallback = 'gemini-2.5-flash-native-audio-preview-12-2025';

  /// Text model for the end-of-lesson review and profile update.
  static const review = 'gemini-3.5-flash-lite';

  /// One-shot speech for the voice preview in Settings.
  static const tts = 'gemini-3.8-flash-lite-tts';
}

/// One function call the model asked for.
class LiveToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;
  const LiveToolCall(this.id, this.name, this.args);
}

/// Everything the tutor session reacts to, decoded from server messages.
sealed class LiveEvent {
  const LiveEvent();
}

class LiveSetupComplete extends LiveEvent {
  const LiveSetupComplete();
}

/// 16-bit little-endian mono PCM at 24 kHz.
class LiveAudio extends LiveEvent {
  final Uint8List pcm;
  const LiveAudio(this.pcm);
}

/// A fragment of what the learner said (fragments arrive incrementally).
class LiveInputTranscript extends LiveEvent {
  final String text;
  const LiveInputTranscript(this.text);
}

/// A fragment of what the tutor is saying.
class LiveOutputTranscript extends LiveEvent {
  final String text;
  const LiveOutputTranscript(this.text);
}

class LiveToolCalls extends LiveEvent {
  final List<LiveToolCall> calls;
  const LiveToolCalls(this.calls);
}

class LiveTurnComplete extends LiveEvent {
  const LiveTurnComplete();
}

/// The server cut its own turn short (the learner barged in).
class LiveInterrupted extends LiveEvent {
  const LiveInterrupted();
}

/// The server will close the connection soon (session time limit).
class LiveGoAway extends LiveEvent {
  const LiveGoAway();
}

/// The connection ended, by either side.
class LiveClosed extends LiveEvent {
  final String? reason;
  const LiveClosed([this.reason]);
}

/// Turns one Firebase Live message into the events the session reacts to.
/// Pure, so the protocol handling is testable without a connection.
List<LiveEvent> liveEventsFrom(LiveServerMessage message) {
  switch (message) {
    case GoingAwayNotice():
      return const [LiveGoAway()];
    case LiveServerToolCall(:final functionCalls):
      final calls = [
        for (final c in functionCalls ?? const <FunctionCall>[])
          LiveToolCall(c.id ?? '', c.name, Map<String, dynamic>.from(c.args)),
      ];
      return calls.isEmpty ? const [] : [LiveToolCalls(calls)];
    case LiveServerContent():
      final events = <LiveEvent>[];
      final heard = message.inputTranscription?.text ?? '';
      if (heard.isNotEmpty) events.add(LiveInputTranscript(heard));
      for (final part in message.modelTurn?.parts ?? const <Part>[]) {
        if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
          events.add(LiveAudio(part.bytes));
        }
      }
      final said = message.outputTranscription?.text ?? '';
      if (said.isNotEmpty) events.add(LiveOutputTranscript(said));
      if (message.interrupted == true) events.add(const LiveInterrupted());
      if (message.turnComplete == true) events.add(const LiveTurnComplete());
      return events;
    default:
      return const [];
  }
}

/// The Gemini Live session, reached through Firebase AI Logic so the app
/// never holds a Gemini key (see [AiBackend]).
class GeminiLiveClient {
  final _events = StreamController<LiveEvent>.broadcast();
  LiveSession? _session;
  StreamSubscription<LiveServerResponse>? _sub;

  Stream<LiveEvent> get events => _events.stream;
  bool get isOpen => _session != null;

  /// Opens a session on [model]. Completes once the server confirms the
  /// setup; throws [LiveConnectException] if it doesn't.
  Future<void> connect({
    required String model,
    required String voice,
    required String systemInstruction,
    required List<Tool> tools,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await close();
    if (!AiBackend.isReady) {
      throw const LiveConnectException('Firebase no está listo',
          unavailable: true);
    }

    final LiveSession session;
    try {
      session = await AiBackend.ai
          .liveGenerativeModel(
            model: model,
            systemInstruction: Content.system(systemInstruction),
            tools: tools,
            liveGenerationConfig: LiveGenerationConfig(
              responseModalities: [ResponseModalities.audio],
              speechConfig:
                  SpeechConfig(voiceName: voice, languageCode: 'fr-FR'),
              // Transcripts of both sides: the learner's drives the chat
              // bubbles and the end-of-lesson review; the tutor's lets the
              // learner read along with what they just heard.
              inputAudioTranscription: AudioTranscriptionConfig(),
              outputAudioTranscription: AudioTranscriptionConfig(),
            ),
          )
          .connect()
          .timeout(timeout);
    } on TimeoutException {
      throw const LiveConnectException('Tiempo de espera agotado');
    } catch (e) {
      throw LiveConnectException('$e', cause: e);
    }
    await _attach(session, timeout);
  }

  /// Runs an already-open session, as [connect] does; lets tests drive the
  /// client with the SDK's `LiveSession.forTesting`.
  @visibleForTesting
  Future<void> attachForTesting(LiveSession session,
          {Duration timeout = const Duration(seconds: 2)}) =>
      _attach(session, timeout);

  Future<void> _attach(LiveSession session, Duration timeout) async {
    _session = session;

    final ready = Completer<void>();
    _sub = session.receive().listen(
      (response) {
        // The server's first message is always its setup confirmation
        // (a type the SDK doesn't export), so any reply means we're live.
        if (!ready.isCompleted) {
          ready.complete();
          _events.add(const LiveSetupComplete());
        }
        for (final event in liveEventsFrom(response.message)) {
          _events.add(event);
        }
      },
      onError: (Object e) {
        debugPrint('GeminiLiveClient stream error: $e');
        if (!ready.isCompleted) {
          ready.completeError(LiveConnectException('$e', cause: e));
        }
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.completeError(
              const LiveConnectException('La conexión se cerró al empezar'));
        }
        if (identical(_session, session)) {
          _session = null;
          _events.add(const LiveClosed());
        }
      },
    );

    try {
      await ready.future.timeout(timeout);
    } on TimeoutException {
      await close();
      throw const LiveConnectException('Tiempo de espera agotado');
    } catch (_) {
      await close();
      rethrow;
    }
  }

  /// Streams 16 kHz mono PCM16 from the mic.
  void sendAudio(Uint8List pcm16k) => _send((s) =>
      s.sendAudioRealtime(InlineDataPart('audio/pcm;rate=16000', pcm16k)));

  /// A text turn (used for app instructions such as the help button).
  void sendText(String text) =>
      _send((s) => s.send(input: Content.text(text), turnComplete: true));

  void sendToolResponses(List<LiveToolCall> calls) =>
      _send((s) => s.sendToolResponse([
            for (final c in calls)
              FunctionResponse(c.name, const {'result': 'ok'}, id: c.id),
          ]));

  void _send(Future<void> Function(LiveSession session) send) {
    final session = _session;
    if (session == null) return;
    send(session).catchError((Object e) {
      debugPrint('GeminiLiveClient send failed: $e');
    });
  }

  /// Closes the session first, then drops the subscription. The other
  /// order hangs: the SDK's receive() is an async* generator, and
  /// cancelling it waits until the server sends another message -- which
  /// after a goodbye may never come, so ending a lesson stalled. Both
  /// steps are bounded so a dead network can't freeze the screen either.
  Future<void> close() async {
    final session = _session;
    _session = null;
    final sub = _sub;
    _sub = null;
    if (session != null) {
      await session
          .close()
          .timeout(const Duration(seconds: 3), onTimeout: () {})
          .catchError((Object e) => debugPrint('Live close failed: $e'));
    }
    await sub
        ?.cancel()
        .timeout(const Duration(seconds: 2), onTimeout: () {})
        .catchError((Object e) => debugPrint('Live cancel failed: $e'));
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}

class LiveConnectException implements Exception {
  final String message;

  /// True when this build can't reach the AI at all (no Firebase config).
  final bool unavailable;
  final Object? cause;

  const LiveConnectException(this.message,
      {this.unavailable = false, this.cause});

  /// The model itself was refused (a withdrawn preview), as opposed to the
  /// network or App Check failing: worth one retry on the fallback model.
  bool get modelRejected {
    final text = message.toLowerCase();
    return text.contains('not found') ||
        text.contains('not supported') ||
        text.contains('1007') ||
        text.contains('1008');
  }

  AiException get asAiException => unavailable
      ? const AiException(unavailable: true)
      : cause != null
          ? AiException.from(cause!)
          : AiException(detail: message);

  @override
  String toString() => 'LiveConnectException: $message';
}
