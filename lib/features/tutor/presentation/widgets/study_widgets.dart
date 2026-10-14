import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/tts_playback_mixin.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/presentation/widgets/phrase_practice.dart';

// The pieces of a phrase study -- tappable words, glosses, phrases to say --
// shared by the conversation review and the translator.

class WordToken extends StatelessWidget {
  final String token;
  final bool selected;
  final VoidCallback onTap;

  const WordToken({
    super.key,
    required this.token,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Escuchar $token',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? p.gold.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border(
              bottom: BorderSide(
                color: selected ? p.gold : p.borderStrong,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            token,
            style: context.texts.headlineSmall?.copyWith(
              color: selected ? p.gold : p.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class WordDetail extends StatelessWidget {
  final String word;
  final WordGloss? gloss;
  final bool pending;
  final VoidCallback onPlay;

  const WordDetail({
    super.key,
    required this.word,
    required this.gloss,
    required this.pending,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final g = gloss;
    return AppCard(
      accent: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g?.word ?? WordGloss.normalize(word),
                    style:
                        context.texts.headlineMedium?.copyWith(color: p.gold)),
                if (g != null && g.ipa.isNotEmpty)
                  Text('/${g.ipa}/', style: AppTheme.ipa(context, size: 17)),
                const SizedBox(height: Insets.sm),
                if (g != null) ...[
                  Text(g.meaningEs,
                      style: context.texts.bodyLarge
                          ?.copyWith(color: p.textPrimary)),
                  if (g.noteEs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(g.noteEs, style: context.texts.bodySmall),
                    ),
                ] else
                  Text(
                    pending
                        ? 'Buscando qué significa…'
                        : 'Sin análisis para esta palabra.',
                    style: context.texts.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Escuchar otra vez',
            onPressed: onPlay,
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
    ).animate(key: ValueKey(word)).fadeIn(duration: Motion.fast).scaleXY(
        begin: 0.97, end: 1, duration: Motion.fast, curve: Curves.easeOutCubic);
  }
}

class GlossRow extends StatelessWidget {
  final WordGloss gloss;
  final bool selected;
  final VoidCallback onTap;

  const GlossRow({
    super.key,
    required this.gloss,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? p.gold.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.md),
        child: Row(
          children: [
            SizedBox(
              width: Sizes.labelColumnWide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gloss.word,
                      style: context.texts.titleMedium
                          ?.copyWith(color: selected ? p.gold : p.textPrimary)),
                  if (gloss.ipa.isNotEmpty)
                    Text('/${gloss.ipa}/',
                        style: AppTheme.ipa(context, size: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gloss.meaningEs,
                      style: context.texts.bodyMedium
                          ?.copyWith(color: p.textPrimary)),
                  if (gloss.noteEs.isNotEmpty)
                    Text(gloss.noteEs, style: context.texts.bodySmall),
                ],
              ),
            ),
            Icon(Icons.volume_up_rounded,
                size: 18, color: selected ? p.gold : p.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A French phrase to learn: listen to it, then say it.
class PhraseCard extends StatefulWidget {
  final String? level;
  final String fr;
  final String es;

  /// Why or when to say it this way; shown under the translation.
  final String note;

  const PhraseCard({
    super.key,
    this.level,
    required this.fr,
    required this.es,
    this.note = '',
  });

  @override
  State<PhraseCard> createState() => _PhraseCardState();
}

class _PhraseCardState extends State<PhraseCard> with TtsPlaybackState {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final level = widget.level;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (level != null && level.isNotEmpty) ...[
                Pill(label: level, tone: p.terracotta, dense: true),
                const SizedBox(width: Insets.sm),
              ],
              Expanded(
                child: Text(widget.fr,
                    style: context.texts.titleMedium
                        ?.copyWith(fontStyle: FontStyle.italic, height: 1.35)),
              ),
              IconButton(
                tooltip: speaking ? 'Parar' : 'Escuchar',
                visualDensity: VisualDensity.compact,
                onPressed: () => speak(widget.fr),
                icon: Icon(
                  speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                  color: p.gold,
                ),
              ),
            ],
          ),
          if (widget.es.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: Insets.xxxl),
              child: Text(widget.es, style: context.texts.bodySmall),
            ),
          if (widget.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: p.gold),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(widget.note,
                        style: context.texts.bodySmall
                            ?.copyWith(color: p.textSecondary)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Insets.md),
          PhrasePractice(target: widget.fr, compact: true),
        ],
      ),
    );
  }
}

class ListenButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const ListenButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: active ? p.gold.withValues(alpha: 0.10) : null,
        side: BorderSide(color: active ? p.gold : p.borderStrong),
      ),
    );
  }
}

class StudySectionTitle extends StatelessWidget {
  final String text;
  const StudySectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Text(text, style: context.texts.headlineSmall),
      );
}

class StudySkeleton extends StatelessWidget {
  const StudySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: Insets.sm),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
          ),
        );
    final calm = MediaQuery.disableAnimationsOf(context);
    final body = Semantics(
      label: 'Analizando la frase',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.gold),
              ),
              const SizedBox(width: Insets.sm),
              Text('Analizando la frase…', style: context.texts.bodySmall),
            ],
          ),
          const SizedBox(height: Insets.lg),
          bar(0.9, 16),
          bar(0.6, 16),
          const SizedBox(height: Insets.lg),
          bar(1, 56),
          bar(1, 56),
        ],
      ),
    );
    if (calm) return body;
    return body
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1400.ms, color: p.gold.withValues(alpha: 0.12));
  }
}

class StudyError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  /// The button's text; "Reintentar" unless the fix is something else.
  final String actionLabel;

  const StudyError({
    super.key,
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Reintentar',
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, color: p.textMuted, size: 20),
              const SizedBox(width: Insets.sm),
              Expanded(child: Text(message, style: context.texts.bodyMedium)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
