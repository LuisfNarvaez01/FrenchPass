import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// French text-to-speech.
///
/// Every entry point is guarded: on a device with no French voice installed the
/// platform channel throws or silently no-ops, and the UI needs to be able to
/// say so rather than appear broken.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _initialised = false;
  bool _available = false;
  double _rate = 0.45;

  /// Whether a usable French voice was found.
  bool get isAvailable => _available;

  final _speakingController = StreamController<bool>.broadcast();
  Stream<bool> get speakingStream => _speakingController.stream;
  bool _speaking = false;
  bool get isSpeaking => _speaking;

  Future<void> init({double rate = 0.45}) async {
    if (_initialised) return;
    _initialised = true;
    _rate = rate;

    try {
      await _tts.awaitSpeakCompletion(true);
      final languages = await _tts.getLanguages;
      final available = (languages as List?)
              ?.map((l) => l.toString().toLowerCase())
              .toList() ??
          const <String>[];

      // Prefer fr-FR, fall back to any French variant (fr-CA, fr_BE, …).
      final match = available.firstWhere(
        (l) => l == 'fr-fr' || l == 'fr_fr',
        orElse: () => available.firstWhere(
          (l) => l.startsWith('fr'),
          orElse: () => '',
        ),
      );

      if (match.isEmpty) {
        // Some engines report no language list but still accept setLanguage.
        await _tts.setLanguage('fr-FR');
      } else {
        await _tts.setLanguage(match);
      }

      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _available = true;

      _tts.setStartHandler(() => _emit(true));
      _tts.setCompletionHandler(() => _emit(false));
      _tts.setCancelHandler(() => _emit(false));
      _tts.setErrorHandler((_) => _emit(false));
    } catch (e) {
      debugPrint('TtsService: French voice unavailable ($e)');
      _available = false;
    }
  }

  void _emit(bool value) {
    _speaking = value;
    if (!_speakingController.isClosed) _speakingController.add(value);
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {
      // Rate is cosmetic; ignore engines that reject it.
    }
  }

  /// Speaks [text] in French. Returns false when no voice could play it.
  ///
  /// Skips the `stop()` round-trip when nothing is currently playing — that
  /// extra platform-channel call was the main source of the "it takes a
  /// moment to start" feeling, since each one blocks on the engine
  /// acknowledging a cancel it didn't need to do.
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    await init(rate: _rate);
    if (!_available) return false;
    try {
      if (_speaking) await _tts.stop();
      _emit(true);
      await _tts.speak(text);
      _emit(false);
      return true;
    } catch (e) {
      debugPrint('TtsService.speak failed: $e');
      _emit(false);
      return false;
    }
  }

  /// Speaks each of [parts] in turn, pausing briefly between them, so a
  /// learner can hear a sentence broken into its words before hearing it at
  /// natural speed. Returns false immediately if no voice is available —
  /// callers should not show a partial read-through on a device with no
  /// French TTS.
  Future<bool> speakSequence(
    List<String> parts, {
    Duration gap = const Duration(milliseconds: 220),
    bool Function()? shouldContinue,
  }) async {
    final cleaned = parts.map((p) => p.trim()).where((p) => p.isNotEmpty);
    await init(rate: _rate);
    if (!_available) return false;

    for (final part in cleaned) {
      if (shouldContinue != null && !shouldContinue()) return true;
      try {
        if (_speaking) await _tts.stop();
        _emit(true);
        await _tts.speak(part);
        _emit(false);
      } catch (e) {
        debugPrint('TtsService.speakSequence failed on "$part": $e');
        _emit(false);
        return false;
      }
      if (gap > Duration.zero) await Future<void>.delayed(gap);
    }
    return true;
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to stop.
    }
    _emit(false);
  }

  void dispose() {
    _speakingController.close();
  }
}
