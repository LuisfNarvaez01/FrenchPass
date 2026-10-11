import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Model ids in one place: preview names change, and swapping one should be
/// a one-line edit.
abstract final class GeminiModels {
  /// Speech-to-speech. Measured at ~0.7 s to first audio.
  static const live = 'gemini-3.1-flash-live-preview';

  /// Fallback if the preview above is withdrawn or rejects the setup.
  static const liveFallback = 'gemini-2.5-flash-native-audio-latest';

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

class LiveClosed extends LiveEvent {
  final int? code;
  final String? reason;
  const LiveClosed(this.code, this.reason);

  /// Close codes the server uses for a rejected key or setup.
  bool get isAuthOrSetupError =>
      code == 1007 || code == 1008 || (reason ?? '').contains('API key');
}

/// Decodes one server frame into zero or more events. Pure, so the protocol
/// handling is testable without a socket.
List<LiveEvent> parseLiveMessage(Object frame) {
  final String raw;
  if (frame is String) {
    raw = frame;
  } else if (frame is List<int>) {
    raw = utf8.decode(frame);
  } else {
    return const [];
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map<String, dynamic>) return const [];

  final events = <LiveEvent>[];
  if (decoded.containsKey('setupComplete')) {
    events.add(const LiveSetupComplete());
  }

  final toolCall = decoded['toolCall'];
  if (toolCall is Map<String, dynamic>) {
    final calls = <LiveToolCall>[];
    for (final c in (toolCall['functionCalls'] as List? ?? const [])) {
      if (c is! Map<String, dynamic>) continue;
      final args = c['args'];
      calls.add(LiveToolCall(
        c['id'] as String? ?? '',
        c['name'] as String? ?? '',
        args is Map<String, dynamic> ? args : const {},
      ));
    }
    if (calls.isNotEmpty) events.add(LiveToolCalls(calls));
  }

  final content = decoded['serverContent'];
  if (content is Map<String, dynamic>) {
    final input = content['inputTranscription'];
    if (input is Map && (input['text'] as String? ?? '').isNotEmpty) {
      events.add(LiveInputTranscript(input['text'] as String));
    }
    final turn = content['modelTurn'];
    if (turn is Map) {
      for (final part in (turn['parts'] as List? ?? const [])) {
        if (part is! Map) continue;
        final inline = part['inlineData'];
        if (inline is Map && inline['data'] is String) {
          events.add(LiveAudio(base64Decode(inline['data'] as String)));
        }
      }
    }
    final output = content['outputTranscription'];
    if (output is Map && (output['text'] as String? ?? '').isNotEmpty) {
      events.add(LiveOutputTranscript(output['text'] as String));
    }
    if (content['interrupted'] == true) events.add(const LiveInterrupted());
    if (content['turnComplete'] == true) events.add(const LiveTurnComplete());
  }

  if (decoded.containsKey('goAway')) events.add(const LiveGoAway());
  return events;
}

/// The setup message that opens a session.
Map<String, dynamic> buildLiveSetup({
  required String model,
  required String voice,
  required String systemInstruction,
  required List<Map<String, dynamic>> tools,
}) =>
    {
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'languageCode': 'fr-FR',
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voice},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'tools': tools,
        // Transcripts of both sides: the learner's drives the chat bubbles
        // and the end-of-lesson review; the tutor's lets the learner read
        // along with what they just heard.
        'inputAudioTranscription': <String, dynamic>{},
        'outputAudioTranscription': <String, dynamic>{},
      },
    };

/// A thin client over the Gemini Live bidirectional WebSocket.
class GeminiLiveClient {
  static const _endpoint = 'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  final _events = StreamController<LiveEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  Stream<LiveEvent> get events => _events.stream;
  bool get isOpen => _channel != null;

  /// Opens the socket and sends [setup]. Completes once the server confirms
  /// the setup; throws [LiveConnectException] if it closes instead.
  Future<void> connect({
    required String apiKey,
    required Map<String, dynamic> setup,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await close();
    final channel = IOWebSocketChannel.connect(
      Uri.parse(_endpoint),
      // Header rather than query string, so the key never lands in a URL
      // that might be logged.
      headers: {'x-goog-api-key': apiKey},
      connectTimeout: timeout,
      pingInterval: const Duration(seconds: 20),
    );
    _channel = channel;

    final ready = Completer<void>();
    _sub = channel.stream.listen(
      (frame) {
        for (final event in parseLiveMessage(frame as Object)) {
          if (event is LiveSetupComplete && !ready.isCompleted) {
            ready.complete();
          }
          _events.add(event);
        }
      },
      onError: (Object e) {
        debugPrint('GeminiLiveClient socket error: $e');
        if (!ready.isCompleted) ready.completeError(LiveConnectException('$e'));
      },
      onDone: () {
        final closed = LiveClosed(channel.closeCode, channel.closeReason);
        if (!ready.isCompleted) {
          ready.completeError(LiveConnectException(
              channel.closeReason ?? 'Conexión cerrada (${channel.closeCode})',
              closed: closed));
        }
        if (identical(_channel, channel)) _channel = null;
        _events.add(closed);
      },
    );

    try {
      await channel.ready.timeout(timeout);
      channel.sink.add(jsonEncode(setup));
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
  void sendAudio(Uint8List pcm16k) => _send({
        'realtimeInput': {
          'audio': {
            'mimeType': 'audio/pcm;rate=16000',
            'data': base64Encode(pcm16k),
          },
        },
      });

  /// A text turn (used for app instructions such as the help button).
  void sendText(String text) => _send({
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': text},
              ],
            },
          ],
          'turnComplete': true,
        },
      });

  void sendToolResponses(List<LiveToolCall> calls) => _send({
        'toolResponse': {
          'functionResponses': [
            for (final c in calls)
              {
                'id': c.id,
                'name': c.name,
                'response': {'result': 'ok'},
              },
          ],
        },
      });

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('GeminiLiveClient send failed: $e');
    }
  }

  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    await _sub?.cancel();
    _sub = null;
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}

class LiveConnectException implements Exception {
  final String message;
  final LiveClosed? closed;
  const LiveConnectException(this.message, {this.closed});

  @override
  String toString() => 'LiveConnectException: $message';
}
