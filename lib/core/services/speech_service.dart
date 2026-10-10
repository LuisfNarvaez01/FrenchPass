import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Outcome of a listening session, so the UI can distinguish "you said nothing"
/// from "the microphone was denied" from "this device has no recognizer".
enum SpeechOutcome { ok, noMatch, permissionDenied, unavailable, error }

class SpeechResult {
  final SpeechOutcome outcome;
  final String transcript;
  final String? message;

  const SpeechResult(this.outcome, {this.transcript = '', this.message});

  bool get isSuccess => outcome == SpeechOutcome.ok && transcript.isNotEmpty;
}

/// French speech recognition on top of `speech_to_text`.
class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _initialised = false;
  bool _available = false;
  String _localeId = 'fr_FR';

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  /// Asks for the microphone and initialises the recognizer.
  Future<SpeechOutcome> prepare() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return SpeechOutcome.permissionDenied;

    if (!_initialised) {
      try {
        _available = await _speech.initialize(
          onError: (e) => debugPrint('SpeechService error: ${e.errorMsg}'),
          debugLogging: false,
        );
        _initialised = true;

        if (_available) {
          final locales = await _speech.locales();
          final french = locales.firstWhere(
            (l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'fr_fr',
            orElse: () => locales.firstWhere(
              (l) => l.localeId.toLowerCase().startsWith('fr'),
              orElse: () => LocaleName('fr_FR', 'Français'),
            ),
          );
          _localeId = french.localeId;
        }
      } catch (e) {
        debugPrint('SpeechService.initialize failed: $e');
        _available = false;
        _initialised = true;
      }
    }

    return _available ? SpeechOutcome.ok : SpeechOutcome.unavailable;
  }

  /// Listens until the speaker pauses, then returns the best transcript.
  ///
  /// [onPartial] receives interim transcripts and [onLevel] the microphone
  /// amplitude (used to drive the live waveform).
  Future<SpeechResult> listenOnce({
    Duration maxDuration = const Duration(seconds: 6),
    Duration pauseFor = const Duration(seconds: 2),
    void Function(String transcript)? onPartial,
    void Function(double level)? onLevel,
  }) async {
    final ready = await prepare();
    if (ready != SpeechOutcome.ok) return SpeechResult(ready);

    var transcript = '';
    try {
      await _speech.listen(
        onSoundLevelChange: onLevel == null
            ? null
            : (level) {
                // Android reports roughly -2..10 dB; normalise to 0..1.
                onLevel(((level + 2) / 12).clamp(0.0, 1.0));
              },
        onResult: (result) {
          transcript = result.recognizedWords;
          onPartial?.call(transcript);
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: maxDuration,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('SpeechService.listen failed: $e');
      return SpeechResult(SpeechOutcome.error, message: '$e');
    }

    // `listen` returns immediately; wait for the recognizer to settle.
    final deadline = DateTime.now().add(maxDuration + const Duration(seconds: 2));
    while (_speech.isListening && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await stop();

    if (transcript.trim().isEmpty) {
      return const SpeechResult(SpeechOutcome.noMatch);
    }
    return SpeechResult(SpeechOutcome.ok, transcript: transcript.trim());
  }

  Future<void> stop() async {
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {
      // Already stopped.
    }
  }

  Future<void> cancel() async {
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {
      // Already cancelled.
    }
  }
}
