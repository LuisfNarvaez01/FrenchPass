import 'package:flutter/material.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';

/// Shared "listen" state machine: a plain full-speed read, or a word-by-word
/// read followed by the full sentence. Was duplicated near-verbatim across
/// the home and word-detail screens; both now mix this in instead.
///
/// A host widget reads [speaking]/[sequenceSpeaking] in its `build` to drive
/// button icons and disabled states, and calls [speak]/[speakWordByWord] from
/// its gesture handlers.
mixin TtsPlaybackState<T extends StatefulWidget> on State<T> {
  final TtsService _tts = getIt<TtsService>();

  bool speaking = false;
  bool sequenceSpeaking = false;
  bool _cancelSequence = false;

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> speak(String text) async {
    if (speaking) {
      await _tts.stop();
      if (mounted) setState(() => speaking = false);
      return;
    }
    setState(() => speaking = true);
    final ok = await _tts.speak(text);
    if (!mounted) return;
    setState(() => speaking = false);
    if (!ok) showNoVoiceSnackBar();
  }

  /// Speaks [sentence] one word at a time, then the whole sentence at
  /// natural speed -- so a learner who only gets the gist from the fast full
  /// read can hear each word isolated first.
  Future<void> speakWordByWord(String sentence) async {
    if (sequenceSpeaking) {
      _cancelSequence = true;
      await _tts.stop();
      if (mounted) setState(() => sequenceSpeaking = false);
      return;
    }
    _cancelSequence = false;
    setState(() => sequenceSpeaking = true);

    final words = sentence
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    final ok = await _tts.speakSequence(
      [...words, sentence],
      shouldContinue: () => !_cancelSequence,
    );

    if (!mounted) return;
    setState(() => sequenceSpeaking = false);
    if (!ok) showNoVoiceSnackBar();
  }

  /// Silences whatever is playing, e.g. before the host swaps the word it is
  /// showing.
  Future<void> stopSpeaking() async {
    _cancelSequence = true;
    await _tts.stop();
    if (mounted) {
      setState(() {
        speaking = false;
        sequenceSpeaking = false;
      });
    }
  }

  void showNoVoiceSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No hay una voz francesa instalada en este dispositivo. '
          'Instálala en Ajustes de Android › Idioma › Texto a voz.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }
}
