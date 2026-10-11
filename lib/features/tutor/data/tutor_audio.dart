import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Microphone in, speaker out -- behind an interface so the session logic
/// can be tested without audio hardware.
abstract class TutorAudio {
  /// Asks for the microphone; false if denied.
  Future<bool> requestMicrophone();

  /// Starts streaming 16 kHz mono PCM16 chunks to [onChunk]. [onLevel]
  /// receives a 0..1 loudness estimate per chunk, for the listening meter.
  Future<void> startMic({
    required void Function(Uint8List pcm) onChunk,
    void Function(double level)? onLevel,
  });

  Future<void> stopMic();

  /// Queues 24 kHz mono PCM16 for playback.
  Future<void> play(Uint8List pcm);

  /// Drops everything queued and goes silent immediately.
  Future<void> stopPlayback();

  /// Fires once each time the queued audio has finished playing.
  Stream<void> get playbackDrained;

  bool get isPlaying;

  Future<void> dispose();
}

class DeviceTutorAudio implements TutorAudio {
  static const _inRate = 16000;
  static const _outRate = 24000;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;

  bool _playerReady = false;
  final _drained = StreamController<void>.broadcast();
  Timer? _drainTimer;
  DateTime _playEndsAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<void> get playbackDrained => _drained.stream;

  @override
  bool get isPlaying => _drainTimer?.isActive ?? false;

  @override
  Future<bool> requestMicrophone() async =>
      (await Permission.microphone.request()).isGranted;

  @override
  Future<void> startMic({
    required void Function(Uint8List pcm) onChunk,
    void Function(double level)? onLevel,
  }) async {
    await stopMic();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _inRate,
      numChannels: 1,
      // Echo cancellation keeps the tutor's own voice out of the mic if the
      // learner talks over it; noise suppression stays off because it can
      // smear exactly the sounds a pronunciation check needs to hear.
      echoCancel: true,
      autoGain: true,
      noiseSuppress: false,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceRecognition,
      ),
    ));
    _micSub = stream.listen((chunk) {
      onChunk(chunk);
      if (onLevel != null) onLevel(pcmLevel(chunk));
    });
  }

  @override
  Future<void> stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  Future<void> _ensurePlayer() async {
    if (_playerReady) return;
    await FlutterPcmSound.setLogLevel(LogLevel.error);
    await FlutterPcmSound.setup(sampleRate: _outRate, channelCount: 1);
    // Feeding is push-based (chunks are queued as they arrive), so the
    // callback has nothing to do; it is registered only so the platform's
    // low-buffer notifications have a handler.
    FlutterPcmSound.setFeedCallback((_) {});
    _playerReady = true;
  }

  @override
  Future<void> play(Uint8List pcm) async {
    if (pcm.length < 2) return;
    await _ensurePlayer();
    // feed() sends the whole backing buffer, so hand it a tight copy rather
    // than a view into a larger one.
    final copy = Uint8List.fromList(pcm);
    await FlutterPcmSound.feed(PcmArrayInt16(bytes: copy.buffer.asByteData()));

    // Track when the queue runs dry from the audio actually fed, so "the
    // tutor finished speaking" does not depend on platform callbacks.
    final now = DateTime.now();
    final start = _playEndsAt.isAfter(now) ? _playEndsAt : now;
    final ms = (copy.length ~/ 2) * 1000 ~/ _outRate;
    _playEndsAt = start.add(Duration(milliseconds: ms));
    _drainTimer?.cancel();
    _drainTimer = Timer(
      // A little slack for the platform's own output latency.
      _playEndsAt.difference(now) + const Duration(milliseconds: 250),
      () {
        if (!_drained.isClosed) _drained.add(null);
      },
    );
  }

  @override
  Future<void> stopPlayback() async {
    _drainTimer?.cancel();
    _drainTimer = null;
    _playEndsAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (_playerReady) {
      // The plugin has no flush; releasing drops the queue and the next
      // play() sets the track up again.
      _playerReady = false;
      try {
        await FlutterPcmSound.release();
      } catch (e) {
        debugPrint('DeviceTutorAudio.stopPlayback: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    await stopMic();
    await stopPlayback();
    await _recorder.dispose();
    await _drained.close();
  }
}

/// RMS loudness of a PCM16 chunk, mapped to 0..1 on a perceptual-ish curve.
double pcmLevel(Uint8List pcm) {
  final samples = pcm.length ~/ 2;
  if (samples == 0) return 0;
  final view = ByteData.sublistView(pcm);
  var sum = 0.0;
  for (var i = 0; i < samples; i++) {
    final s = view.getInt16(i * 2, Endian.little) / 32768.0;
    sum += s * s;
  }
  final rms = math.sqrt(sum / samples);
  if (rms <= 0) return 0;
  // -50 dBFS → 0, -10 dBFS → 1.
  final db = 20 * math.log(rms) / math.ln10;
  return ((db + 50) / 40).clamp(0.0, 1.0);
}
