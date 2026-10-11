import 'package:flutter/material.dart';

import 'package:french_pass/core/theme/app_theme.dart';

/// Two listening modes for the example sentence: word by word, then at
/// natural speed -- the first time someone hears the fast version it is easy
/// to assume the app is stuck, so the slower path is offered right beside it.
class ExampleAudioRow extends StatelessWidget {
  final bool isSpeakingWord;
  final bool isSpeakingSequence;
  final VoidCallback onWordByWord;
  final VoidCallback onFullSentence;

  const ExampleAudioRow({
    super.key,
    required this.isSpeakingWord,
    required this.isSpeakingSequence,
    required this.onWordByWord,
    required this.onFullSentence,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSpeakingWord ? null : onWordByWord,
            icon: Icon(
              isSpeakingSequence
                  ? Icons.stop_circle_outlined
                  : Icons.format_list_numbered_rounded,
              size: 18,
              color: p.gold,
            ),
            label: Text(isSpeakingSequence ? 'Detener' : 'Palabra por palabra'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSpeakingSequence ? null : onFullSentence,
            icon: Icon(
              isSpeakingWord
                  ? Icons.graphic_eq_rounded
                  : Icons.record_voice_over_outlined,
              size: 18,
              color: p.gold,
            ),
            label: const Text('Frase completa'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: p.border),
            ),
          ),
        ),
      ],
    );
  }
}
