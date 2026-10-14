import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/text/answer_check.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';

/// The frame every exercise shares: back button, title, and how far along
/// the session is.
class PracticeScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  /// 0 to 1, or null to hide the bar.
  final double? progress;
  final List<Widget> actions;

  const PracticeScaffold({
    super.key,
    required this.title,
    required this.child,
    this.progress,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: AppTopBar(title: title)),
                  ...actions,
                ],
              ),
              if (progress case final value?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, 0, Insets.page, Insets.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      color: p.gold,
                      backgroundColor: p.surfaceAlt,
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round button that reads French aloud.
class SpeakButton extends StatefulWidget {
  final String text;
  final bool slow;
  final double size;
  final String? tooltip;

  const SpeakButton({
    super.key,
    required this.text,
    this.slow = false,
    this.size = 56,
    this.tooltip,
  });

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _busy = false;

  Future<void> _speak() async {
    final tts = getIt<TtsService>();
    setState(() => _busy = true);
    final ok = widget.slow
        ? await tts.speakSlowly(widget.text)
        : await tts.speak(widget.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay voz francesa en este teléfono. '
              'Instálala en Ajustes de Android › Texto a voz.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: IconButton.filled(
        tooltip:
            widget.tooltip ?? (widget.slow ? 'Escuchar despacio' : 'Escuchar'),
        onPressed: _busy ? null : _speak,
        style: IconButton.styleFrom(
          backgroundColor: widget.slow ? p.surfaceAlt : p.gold,
          foregroundColor: widget.slow ? p.gold : p.onGold,
        ),
        icon: Icon(
          _busy
              ? Icons.graphic_eq_rounded
              : widget.slow
                  ? Icons.slow_motion_video_rounded
                  : Icons.volume_up_rounded,
          size: widget.size * 0.45,
        ),
      ),
    );
  }
}

/// One multiple-choice question; tells its parent when answered and when
/// the learner moves on.
class ChoiceQuestion extends StatefulWidget {
  final ChoiceItem item;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;
  final bool isLast;

  /// French options get a speaker after answering.
  final bool optionsAreFrench;
  final Widget? header;

  const ChoiceQuestion({
    super.key,
    required this.item,
    required this.onAnswered,
    required this.onNext,
    this.isLast = false,
    this.optionsAreFrench = false,
    this.header,
  });

  @override
  State<ChoiceQuestion> createState() => _ChoiceQuestionState();
}

class _ChoiceQuestionState extends State<ChoiceQuestion> {
  int? _picked;

  @override
  void didUpdateWidget(ChoiceQuestion old) {
    super.didUpdateWidget(old);
    if (!identical(old.item, widget.item)) _picked = null;
  }

  void _pick(int i) {
    if (_picked != null) return;
    setState(() => _picked = i);
    widget.onAnswered(i == widget.item.answer);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final answered = _picked != null;
    final right = _picked == item.answer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
      children: [
        if (widget.header != null) ...[
          widget.header!,
          const SizedBox(height: Insets.lg),
        ],
        Text(item.prompt,
            style: context.texts.headlineSmall?.copyWith(height: 1.35)),
        const SizedBox(height: Insets.xl),
        for (final (i, option) in item.options.indexed) ...[
          _OptionButton(
            label: option,
            state: !answered
                ? _OptionState.idle
                : i == item.answer
                    ? _OptionState.right
                    : i == _picked
                        ? _OptionState.wrong
                        : _OptionState.dim,
            onTap: () => _pick(i),
          ),
          const SizedBox(height: Insets.sm),
        ],
        if (answered) ...[
          const SizedBox(height: Insets.md),
          FeedbackBanner(
            right: right,
            title: right ? 'Correcto' : 'Era «${item.correct}»',
            detail: item.why,
            speak: widget.optionsAreFrench ? item.correct : null,
          ).animate().fadeIn(duration: Motion.fast),
          const SizedBox(height: Insets.lg),
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: Text(widget.isLast ? 'Ver resultado' : 'Siguiente'),
          ),
        ],
      ],
    );
  }
}

enum _OptionState { idle, right, wrong, dim }

class _OptionButton extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (border, fill, icon) = switch (state) {
      _OptionState.right => (
          p.good,
          p.good.withValues(alpha: 0.12),
          Icons.check_circle_rounded
        ),
      _OptionState.wrong => (
          p.critical,
          p.critical.withValues(alpha: 0.10),
          Icons.cancel_rounded
        ),
      _OptionState.dim => (p.border, p.surface, null),
      _OptionState.idle => (p.border, p.surface, null),
    };
    return Opacity(
      opacity: state == _OptionState.dim ? 0.6 : 1,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: state == _OptionState.idle ? onTap : null,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg, vertical: Insets.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: context.texts.bodyLarge)),
                if (icon != null) Icon(icon, color: border, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Right or wrong, with the reason, after an answer.
class FeedbackBanner extends StatelessWidget {
  final bool right;
  final String title;
  final String detail;

  /// French to read aloud from the banner (the correct answer).
  final String? speak;

  /// Amber instead of green: right, with a caveat (accents).
  final bool almost;

  const FeedbackBanner({
    super.key,
    required this.right,
    required this.title,
    this.detail = '',
    this.speak,
    this.almost = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = !right
        ? p.critical
        : almost
            ? p.warning
            : p.good;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            right ? Icons.check_circle_rounded : Icons.info_rounded,
            color: tone,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleMedium),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: context.texts.bodySmall),
                ],
              ],
            ),
          ),
          if (speak != null) SpeakButton(text: speak!, size: 40),
        ],
      ),
    );
  }
}

/// A typed French answer, checked with [AnswerCheck].
class TypedAnswer extends StatefulWidget {
  final String expected;
  final ValueChanged<AnswerMatch> onChecked;
  final VoidCallback onNext;
  final bool isLast;
  final String hint;

  /// Extra lines under the feedback (translation, written form...).
  final String detail;

  /// Numeric keyboard (numbers and times).
  final bool numeric;

  /// Custom comparison, for answers that aren't plain French text.
  final AnswerMatch Function(String typed)? compare;

  const TypedAnswer({
    super.key,
    required this.expected,
    required this.onChecked,
    required this.onNext,
    this.isLast = false,
    this.hint = 'Escribe tu respuesta',
    this.detail = '',
    this.numeric = false,
    this.compare,
  });

  @override
  State<TypedAnswer> createState() => _TypedAnswerState();
}

class _TypedAnswerState extends State<TypedAnswer> {
  final _controller = TextEditingController();
  AnswerMatch? _result;

  @override
  void didUpdateWidget(TypedAnswer old) {
    super.didUpdateWidget(old);
    if (old.expected != widget.expected) {
      _controller.clear();
      _result = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (_result != null || _controller.text.trim().isEmpty) return;
    final result = widget.compare?.call(_controller.text) ??
        AnswerCheck.check(_controller.text, widget.expected);
    setState(() => _result = result);
    widget.onChecked(result);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final result = _result;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: p.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: result == null,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType:
              widget.numeric ? TextInputType.datetime : TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _check(),
          style: context.texts.titleMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: p.surface,
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide: BorderSide(color: p.gold, width: 1.5)),
          ),
        ),
        const SizedBox(height: Insets.md),
        if (result == null)
          ElevatedButton(
            onPressed: _check,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Comprobar'),
          )
        else ...[
          FeedbackBanner(
            right: result.isRight,
            almost: result == AnswerMatch.accents,
            title: switch (result) {
              AnswerMatch.exact => 'Correcto',
              AnswerMatch.accents => 'Casi: revisa los acentos',
              AnswerMatch.wrong => 'La respuesta era otra',
            },
            detail: [
              if (result != AnswerMatch.exact) widget.expected,
              if (widget.detail.isNotEmpty) widget.detail,
            ].join('\n'),
          ).animate().fadeIn(duration: Motion.fast),
          const SizedBox(height: Insets.lg),
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: Text(widget.isLast ? 'Ver resultado' : 'Siguiente'),
          ),
        ],
      ],
    );
  }
}

/// The end of a session: score, the mascot when it went well, and what
/// to do next.
class SessionSummary extends StatelessWidget {
  final int correct;
  final int total;
  final VoidCallback onAgain;
  final String againLabel;

  const SessionSummary({
    super.key,
    required this.correct,
    required this.total,
    required this.onAgain,
    this.againLabel = 'Otra ronda',
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : correct / total;
    final good = ratio >= 0.7;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.xl, Insets.page, Insets.xxxl),
      children: [
        Center(
          child: good
              ? MascotCelebration(
                  size: 120,
                  caption: ratio == 1 ? 'Perfecto' : 'Muy bien',
                )
              : const MascotSticker(size: 120, pose: MascotPose.thinking),
        ),
        const SizedBox(height: Insets.xl),
        Text('$correct de $total',
            textAlign: TextAlign.center, style: context.texts.displaySmall),
        const SizedBox(height: Insets.xs),
        Text(
          good
              ? 'Cuenta para tu meta de hoy y para tu racha.'
              : 'Repite la ronda: lo que fallaste hoy, mañana te sale.',
          textAlign: TextAlign.center,
          style: context.texts.bodySmall,
        ),
        const SizedBox(height: Insets.xxl),
        ElevatedButton(
          onPressed: onAgain,
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(againLabel),
        ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Volver a Practicar'),
        ),
      ],
    );
  }
}
