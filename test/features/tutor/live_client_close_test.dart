// Ending a lesson must not wait for the server: closing the client used to
// hang until the tutor sent another message, which after a goodbye might
// never happen.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A WebSocket that never says anything after setup, like a tutor who has
/// said goodbye.
class _QuietSocket extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  final _outgoing = StreamController<dynamic>();

  void serverSends(Map<String, Object?> message) =>
      _incoming.add(jsonEncode(message));

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _Sink(_outgoing, onClose: _incoming.close);

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

class _Sink implements WebSocketSink {
  final StreamController<dynamic> _out;
  final Future<void> Function() onClose;
  _Sink(this._out, {required this.onClose});

  @override
  void add(dynamic data) => _out.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) => onClose();

  @override
  Future<void> get done => Future.value();
}

void main() {
  test('close() returns at once even when the server has gone quiet', () async {
    final socket = _QuietSocket();
    final client = GeminiLiveClient();
    final attached = client.attachForTesting(LiveSession.forTesting(socket));
    socket.serverSends({'setupComplete': <String, Object?>{}});
    await attached;
    expect(client.isOpen, isTrue);
    // As in a real lesson: some time passes after the tutor's last message,
    // so the SDK is already waiting for the next one when we close.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final sw = Stopwatch()..start();
    await client.close();
    expect(client.isOpen, isFalse);
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'closing waited on the server');
  });
}
