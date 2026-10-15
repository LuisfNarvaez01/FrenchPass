import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// A word as the hero of the screen: set like a magazine headline, with its
/// sound beside the reading and the example underneath. Listening lives
/// inside the card, next to what it plays, so the only button below it is
/// the one that matters: practise.
class WordHero extends StatelessWidget {
  final Word word;

  /// The small line above the word; defaults to its category and type.
  final String? eyebrow;

  final bool speaking;
  final bool sequenceSpeaking;
  final VoidCallback onListen;
  final VoidCallback onSentence;
  final VoidCallback onWordByWord;

  const WordHero({
    super.key,
    required this.word,
    this.eyebrow,
    required this.speaking,
    required this.sequenceSpeaking,
    required this.onListen,
    required this.onSentence,
    required this.onWordByWord,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      radius: Radii.xl,
      padding:
          const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (eyebrow ??
                          '${word.category.labelEs} · ${word.wordType.labelEs}')
                      .toUpperCase(),
                  style: AppTheme.eyebrow(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Pill(label: word.level.label, tone: p.textSecondary, dense: true),
            ],
          ),
          const SizedBox(height: Insets.xl),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(word.french, style: AppTheme.french(context, size: 44)),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: onListen,
                  child: Text(word.ipa, style: AppTheme.ipa(context, size: 18)),
                ),
              ),
              const SizedBox(width: Insets.sm),
              _ListenButton(speaking: speaking, onTap: onListen),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(word.translationEs,
              style: context.texts.titleLarge?.copyWith(fontSize: 20)),
          const SizedBox(height: Insets.xl),
          _Example(
            word: word,
            speaking: speaking,
            sequenceSpeaking: sequenceSpeaking,
            onSentence: onSentence,
            onWordByWord: onWordByWord,
          ),
        ],
      ),
    );
  }
}

/// The round play control beside the reading. While the word plays, it
/// pulses with it.
class _ListenButton extends StatelessWidget {
  final bool speaking;
  final VoidCallback onTap;
  const _ListenButton({required this.speaking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final icon = Icon(
      speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
      size: 20,
      color: speaking ? p.gold : p.textPrimary,
    );
    return Semantics(
      button: true,
      label: 'Escuchar la palabra',
      child: Material(
        color: p.surfaceAlt,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: speaking && !MediaQuery.disableAnimationsOf(context)
                  ? icon
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 0.85, end: 1.15, duration: 380.ms)
                  : icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// The example sentence, marked by a thin rule rather than boxed in, with
/// its two ways to listen as quiet text links.
class _Example extends StatelessWidget {
  final Word word;
  final bool speaking;
  final bool sequenceSpeaking;
  final VoidCallback onSentence;
  final VoidCallback onWordByWord;

  const _Example({
    required this.word,
    required this.speaking,
    required this.sequenceSpeaking,
    required this.onSentence,
    required this.onWordByWord,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final link = TextButton.styleFrom(
      foregroundColor: p.textSecondary,
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return Container(
      padding: const EdgeInsets.only(left: Insets.md),
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: p.gold.withValues(alpha: 0.55), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word.exampleFr,
            style: context.texts.bodyLarge?.copyWith(
              color: p.textPrimary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(word.exampleEs, style: context.texts.bodySmall),
          const SizedBox(height: Insets.xs),
          Wrap(
            children: [
              TextButton.icon(
                style: link,
                onPressed: sequenceSpeaking ? null : onSentence,
                icon: Icon(
                    speaking
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    size: 18),
                label: const Text('Escuchar frase'),
              ),
              TextButton.icon(
                style: link,
                onPressed: speaking && !sequenceSpeaking ? null : onWordByWord,
                icon: Icon(
                    sequenceSpeaking
                        ? Icons.stop_rounded
                        : Icons.slow_motion_video_rounded,
                    size: 18),
                label:
                    Text(sequenceSpeaking ? 'Detener' : 'Palabra por palabra'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one gold button under a word, with saving as a quiet companion.
class WordActions extends StatelessWidget {
  final VoidCallback onPractice;
  final VoidCallback onSave;
  final bool isSaved;

  const WordActions({
    super.key,
    required this.onPractice,
    required this.onSave,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onPractice,
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: const Text('Practicar esta palabra'),
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        SizedBox(
          width: 56,
          height: 56,
          child: OutlinedButton(
            onPressed: onSave,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                  color: isSaved ? p.gold.withValues(alpha: 0.6) : p.border),
            ),
            child: Semantics(
              label: isSaved ? 'Quitar de guardadas' : 'Guardar palabra',
              child: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isSaved ? p.gold : p.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
