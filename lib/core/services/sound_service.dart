import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';

/// The moments that make a sound. Ordinary taps stay silent.
enum AppSound {
  /// A right answer: two rising notes.
  correct,

  /// A wrong answer: one soft, low note, never a buzzer.
  wrong,

  /// A round or lesson finished: a short rising arpeggio.
  complete,

  /// An achievement or the daily goal: a bright chord that rings out.
  achievement,
}

/// Short UI sounds, synthesised on the device (no audio files, nothing to
/// license) and played through the same PCM player the tutor uses.
class SoundService {
  final StorageService _storage;
  SoundService(this._storage);

  static const _rate = 24000;

  /// On unless the learner turned it off in Ajustes.
  bool get enabled => _storage.getBool(StorageKeys.soundsEnabled) ?? true;

  Future<void> setEnabled(bool value) =>
      _storage.setBool(StorageKeys.soundsEnabled, value);

  final Map<AppSound, Int16List> _cache = {};

  /// Tests have no audio device.
  @visibleForTesting
  static bool muted = false;

  Future<void> play(AppSound sound) async {
    if (!enabled || muted) return;
    final pcm = _cache[sound] ??= synthesize(sound);
    try {
      // The tutor releases the player when a lesson ends, so it is set up
      // again for every sound; at this rate that costs nothing audible.
      await FlutterPcmSound.setup(sampleRate: _rate, channelCount: 1);
      FlutterPcmSound.setFeedCallback((_) {});
      await FlutterPcmSound.feed(PcmArrayInt16(bytes: pcm.buffer.asByteData()));
    } catch (e) {
      debugPrint('SoundService.play: $e');
    }
  }

  /// The samples for [sound]: sine notes with a soft attack and an
  /// exponential tail, plus a quiet octave for warmth.
  @visibleForTesting
  static Int16List synthesize(AppSound sound) {
    final notes = switch (sound) {
      AppSound.correct => const [(659.25, 0.0, 0.16), (987.77, 0.09, 0.30)],
      AppSound.wrong => const [(233.08, 0.0, 0.28), (196.0, 0.07, 0.30)],
      AppSound.complete => const [
          (523.25, 0.0, 0.22),
          (659.25, 0.09, 0.22),
          (783.99, 0.18, 0.22),
          (1046.5, 0.27, 0.55),
        ],
      AppSound.achievement => const [
          (783.99, 0.0, 0.8),
          (987.77, 0.04, 0.8),
          (1174.66, 0.08, 0.8),
          (1567.98, 0.16, 0.6),
        ],
    };
    final volume = sound == AppSound.wrong ? 0.22 : 0.18;
    final length = notes.map((n) => n.$2 + n.$3).reduce(math.max);
    final out = Float64List((length * _rate).ceil() + 1);
    for (final (freq, start, dur) in notes) {
      final s0 = (start * _rate).round();
      final count = (dur * _rate).round();
      for (var i = 0; i < count && s0 + i < out.length; i++) {
        final t = i / _rate;
        final attack = math.min(1.0, t / 0.006);
        final decay = math.exp(-t * (4.5 / dur));
        final wave = math.sin(2 * math.pi * freq * t) +
            0.18 * math.sin(4 * math.pi * freq * t);
        out[s0 + i] += wave * attack * decay;
      }
    }
    final peak = out.fold<double>(0, (m, v) => math.max(m, v.abs()));
    final scale = peak == 0 ? 0 : volume * 32767 / peak;
    return Int16List.fromList([for (final v in out) (v * scale).round()]);
  }
}

/// Plays [sound] if the app has a [SoundService] (widget tests may not).
void playSound(AppSound sound) {
  if (getIt.isRegistered<SoundService>()) getIt<SoundService>().play(sound);
}

/// Plays [sound] once, when [child] first appears: a result screen, a
/// banner for something just earned.
class SoundOnMount extends StatefulWidget {
  final AppSound? sound;
  final Widget child;
  const SoundOnMount({super.key, required this.sound, required this.child});

  @override
  State<SoundOnMount> createState() => _SoundOnMountState();
}

class _SoundOnMountState extends State<SoundOnMount> {
  @override
  void initState() {
    super.initState();
    if (widget.sound case final sound?) playSound(sound);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
