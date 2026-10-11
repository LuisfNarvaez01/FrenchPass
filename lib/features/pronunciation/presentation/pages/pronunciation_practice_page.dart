import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/speech_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/pronunciation/domain/usecases/pronunciation_scorer.dart';
import 'package:french_pass/features/pronunciation/presentation/pages/pronunciation_result_page.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

enum _Phase { idle, listening, scoring }

class PronunciationPracticePage extends StatefulWidget {
  /// Passed through navigation when available; [wordId] is the fallback for a
  /// cold start where `extra` did not survive.
  final Word? word;
  final String wordId;

  const PronunciationPracticePage({
    super.key,
    this.word,
    required this.wordId,
  });

  @override
  State<PronunciationPracticePage> createState() =>
      _PronunciationPracticePageState();
}

class _PronunciationPracticePageState extends State<PronunciationPracticePage> {
  final _speech = getIt<SpeechService>();
  final _tts = getIt<TtsService>();

  _Phase _phase = _Phase.idle;
  String _partial = '';
  double _level = 0;
  String? _error;

  late final Word? _word =
      widget.word ?? getIt<WordRepository>().byId(widget.wordId);

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }

  String get _statusText => switch (_phase) {
        _Phase.idle => _error ?? 'Toca el micrófono y pronuncia',
        _Phase.listening => 'Escuchando…',
        _Phase.scoring => 'Analizando tu pronunciación…',
      };

  Future<void> _start() async {
    final word = _word;
    if (word == null || _phase != _Phase.idle) return;

    await _tts.stop();
    setState(() {
      _phase = _Phase.listening;
      _partial = '';
      _level = 0;
      _error = null;
    });

    final result = await _speech.listenOnce(
      onPartial: (text) {
        if (mounted) setState(() => _partial = text);
      },
      onLevel: (level) {
        if (mounted) setState(() => _level = level);
      },
    );

    if (!mounted) return;

    switch (result.outcome) {
      case SpeechOutcome.permissionDenied:
        setState(() {
          _phase = _Phase.idle;
          _error = 'Necesito el micrófono para evaluar tu pronunciación. '
              'Actívalo en los ajustes de la app.';
        });
        return;
      case SpeechOutcome.unavailable:
        setState(() {
          _phase = _Phase.idle;
          _error = 'Este dispositivo no tiene reconocimiento de voz '
              'disponible para francés.';
        });
        return;
      case SpeechOutcome.noMatch:
        setState(() {
          _phase = _Phase.idle;
          _error = 'No te escuché. Acércate al micrófono e inténtalo de nuevo.';
        });
        return;
      case SpeechOutcome.error:
        setState(() {
          _phase = _Phase.idle;
          _error = 'Algo falló al escuchar. Inténtalo otra vez.';
        });
        return;
      case SpeechOutcome.ok:
        break;
    }

    setState(() => _phase = _Phase.scoring);

    final scored = PronunciationScorer.score(
      targetWord: word.french,
      recognizedText: result.transcript,
    );

    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _partial = '';
    });

    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PronunciationResultPage(result: scored, word: word),
      ),
    );
    // "Continuar" on the result closes practice too, landing back on
    // whichever screen opened it (home or the word detail) instead of
    // unwinding the whole stack.
    if (done == true && mounted) context.pop();
  }

  Future<void> _stop() async {
    await _speech.stop();
    if (mounted) setState(() => _phase = _Phase.scoring);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final word = _word;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: word == null
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Palabra no encontrada',
                  message: 'Vuelve e intenta de nuevo.',
                )
              : Column(
                  children: [
                    const AppTopBar(title: 'Práctica'),
                    Expanded(
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: Insets.page),
                        child: Column(
                          children: [
                            const SizedBox(height: Insets.xl),

                            Text('Pronuncia esta palabra',
                                style: AppTheme.eyebrow(context)),
                            const SizedBox(height: Insets.lg),

                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                word.french,
                                style: context.texts.displayMedium
                                    ?.copyWith(color: p.gold),
                                textAlign: TextAlign.center,
                              ),
                            ).animate().fadeIn(duration: Motion.base),

                            const SizedBox(height: Insets.sm),
                            Text(word.ipa,
                                style: AppTheme.ipa(context, size: 18)),
                            const SizedBox(height: Insets.md),
                            Text(
                              word.translationEs,
                              style: context.texts.bodyLarge,
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: Insets.xl),

                            OutlinedButton.icon(
                              onPressed: _phase == _Phase.idle
                                  ? () => _tts.speak(word.french)
                                  : null,
                              icon:
                                  const Icon(Icons.volume_up_rounded, size: 18),
                              label: const Text('Escúchala primero'),
                            ),

                            const SizedBox(height: Insets.xxl),

                            // Live transcript — shows the learner what the
                            // recognizer is actually hearing.
                            SizedBox(
                              height: Sizes.actionHeight,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: Motion.fast,
                                  child: _partial.isEmpty
                                      ? const SizedBox.shrink()
                                      : Container(
                                          key: ValueKey(_partial),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: Insets.lg,
                                              vertical: Insets.md),
                                          decoration: BoxDecoration(
                                            color: p.surfaceAlt,
                                            borderRadius:
                                                BorderRadius.circular(Radii.md),
                                            border: Border.all(color: p.border),
                                          ),
                                          child: Text(
                                            '« $_partial »',
                                            style: context.texts.bodyLarge
                                                ?.copyWith(
                                                    fontStyle:
                                                        FontStyle.italic),
                                            textAlign: TextAlign.center,
                                            // The box has a fixed height so
                                            // the mic never jumps; a long
                                            // partial must not overflow it.
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            _Waveform(
                              active: _phase == _Phase.listening,
                              level: _level,
                              color: p.gold,
                            ),

                            const SizedBox(height: Insets.xl),

                            _MicButton(
                              phase: _phase,
                              level: _level,
                              onTap: switch (_phase) {
                                _Phase.idle => _start,
                                _Phase.listening => _stop,
                                _Phase.scoring => null,
                              },
                            ),

                            const SizedBox(height: Insets.lg),

                            AnimatedSwitcher(
                              duration: Motion.fast,
                              child: Text(
                                _statusText,
                                key: ValueKey(_statusText),
                                textAlign: TextAlign.center,
                                style: context.texts.bodyMedium?.copyWith(
                                  color: _error != null
                                      ? p.critical
                                      : _phase == _Phase.idle
                                          ? p.textSecondary
                                          : p.gold,
                                ),
                              ),
                            ),

                            const SizedBox(height: Insets.xxxl),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Big round record control. Its ring responds to the live microphone level, so
/// the learner can see that the app is picking their voice up.
class _MicButton extends StatelessWidget {
  final _Phase phase;
  final double level;
  final VoidCallback? onTap;

  const _MicButton({
    required this.phase,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final listening = phase == _Phase.listening;
    final scoring = phase == _Phase.scoring;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: Sizes.heroControl,
        height: Sizes.heroControl,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening ? p.gold.withValues(alpha: 0.14) : p.surface,
          border: Border.all(
            color: listening ? p.gold : p.borderStrong,
            width: listening ? 2 + level * 3 : 1.5,
          ),
          boxShadow: listening
              ? [
                  BoxShadow(
                    color: p.gold.withValues(alpha: 0.18 + level * 0.25),
                    blurRadius: 24 + level * 28,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: scoring
              ? SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: p.gold),
                )
              : Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 48,
                  color: listening ? p.gold : p.textSecondary,
                ),
        ),
      ),
    );
  }
}

/// Amplitude bars driven by the real microphone level rather than a canned
/// animation, so a silent room looks silent.
class _Waveform extends StatelessWidget {
  final bool active;
  final double level;
  final Color color;

  const _Waveform({
    required this.active,
    required this.level,
    required this.color,
  });

  static const _bars = 21;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _bars; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: 3,
              height: _heightFor(i),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? 0.85 : 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  double _heightFor(int i) {
    if (!active) return 4;
    // Centre bars react most, so the shape reads as a voice envelope.
    const centre = (_bars - 1) / 2;
    final falloff = 1 - (i - centre).abs() / centre;
    final jitter = 0.55 + 0.45 * math.sin(i * 1.7);
    return (6 + level * 38 * falloff * jitter).clamp(4.0, 46.0);
  }
}
