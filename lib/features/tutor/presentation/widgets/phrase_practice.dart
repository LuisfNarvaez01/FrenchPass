import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/speech_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/pronunciation/domain/entities/pronunciation_result.dart';
import 'package:french_pass/features/pronunciation/domain/usecases/pronunciation_scorer.dart';

/// "Say it yourself": records one attempt at [target], scores it with the
/// same scorer as word practice, and shows what was heard right under the
/// phrase. A clear attempt brings the mascot out.
///
/// Phrases from a conversation are not corpus words, so attempts here do not
/// feed the spaced-repetition schedule.
class PhrasePractice extends StatefulWidget {
  final String target;
  final bool compact;

  /// Each scored attempt.
  final ValueChanged<PronunciationResult>? onResult;

  /// The microphone or the recognizer can't be used on this phone.
  final VoidCallback? onUnavailable;

  const PhrasePractice({
    super.key,
    required this.target,
    this.compact = false,
    this.onResult,
    this.onUnavailable,
  });

  @override
  State<PhrasePractice> createState() => _PhrasePracticeState();
}

enum _Phase { idle, listening }

class _PhrasePracticeState extends State<PhrasePractice> {
  final _speech = getIt<SpeechService>();

  _Phase _phase = _Phase.idle;
  String _partial = '';
  double _level = 0;
  PronunciationResult? _result;
  String? _error;

  @override
  void didUpdateWidget(covariant PhrasePractice old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _result = null;
      _error = null;
      _partial = '';
    }
  }

  @override
  void dispose() {
    if (_phase == _Phase.listening) _speech.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_phase == _Phase.listening) {
      await _speech.stop();
      return;
    }
    await getIt<TtsService>().stop();
    setState(() {
      _phase = _Phase.listening;
      _partial = '';
      _level = 0;
      _error = null;
      _result = null;
    });

    // Longer phrases need longer to say than a single word.
    final words = widget.target.split(RegExp(r'\s+')).length;
    final result = await _speech.listenOnce(
      maxDuration: Duration(seconds: (4 + words * 0.8).clamp(6, 20).round()),
      onPartial: (t) {
        if (mounted) setState(() => _partial = t);
      },
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
    );
    if (!mounted) return;

    final error = switch (result.outcome) {
      SpeechOutcome.ok => null,
      SpeechOutcome.permissionDenied =>
        'Necesito el micrófono. Actívalo en los ajustes de la app.',
      SpeechOutcome.unavailable =>
        'Este teléfono no tiene reconocimiento de voz en francés.',
      SpeechOutcome.noMatch => 'No te escuché. Acércate e inténtalo otra vez.',
      SpeechOutcome.error => 'Algo falló al escuchar. Inténtalo otra vez.',
    };

    final scored = error == null
        ? PronunciationScorer.score(
            targetWord: widget.target, recognizedText: result.transcript)
        : null;

    setState(() {
      _phase = _Phase.idle;
      _error = error;
      _result = scored;
      _partial = '';
    });
    if (scored != null) widget.onResult?.call(scored);
    if (result.outcome == SpeechOutcome.permissionDenied ||
        result.outcome == SpeechOutcome.unavailable) {
      widget.onUnavailable?.call();
    }

    if (scored != null && scored.isSuccess) {
      showMascotToast(context, scored.feedback.labelEs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final listening = _phase == _Phase.listening;
    final result = _result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MicPill(
          listening: listening,
          level: _level,
          label: listening
              ? (_partial.isEmpty ? 'Te escucho…' : '« $_partial »')
              : result == null
                  ? 'Dilo tú'
                  : 'Otra vez',
          onTap: _toggle,
          compact: widget.compact,
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: Insets.sm),
                  child: Text(_error!,
                      style:
                          context.texts.bodySmall?.copyWith(color: p.critical)),
                )
              : result == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: Insets.sm),
                      child: _ResultLine(result: result)
                          .animate()
                          .fadeIn(duration: Motion.fast),
                    ),
        ),
      ],
    );
  }
}

/// The microphone button: a pill whose border pulses with the voice.
class MicPill extends StatelessWidget {
  final bool listening;
  final double level;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const MicPill({
    super.key,
    required this.listening,
    required this.level,
    required this.label,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: listening ? 'Dejar de grabar' : 'Pronunciar esta frase',
      excludeSemantics: true,
      child: Material(
        color: listening ? p.gold.withValues(alpha: 0.14) : p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: compact ? 40 : 48,
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: listening ? p.gold : p.borderStrong,
                width: listening ? 1.5 + level * 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(listening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 20, color: listening ? p.gold : p.textSecondary),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelLarge?.copyWith(
                      color: listening ? p.gold : p.textSecondary,
                      fontStyle: listening && label.startsWith('«')
                          ? FontStyle.italic
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final PronunciationResult result;
  const _ResultLine({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = p.statusFor(result.overallScore);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppPalette.statusIcon(result.overallScore),
                  size: 13, color: tone),
              const SizedBox(width: Insets.xs),
              Text('${result.overallPercent}%',
                  style: context.texts.labelMedium
                      ?.copyWith(color: tone, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            'Escuché « ${result.recognizedText} ». ${result.feedback.subtitle}.',
            style: context.texts.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
