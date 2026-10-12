import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/tts_playback_mixin.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';
import 'package:french_pass/features/tutor/presentation/cubit/session_review_cubit.dart';
import 'package:french_pass/features/tutor/presentation/widgets/phrase_practice.dart';
import 'package:french_pass/features/tutor/presentation/widgets/tutor_note_card.dart';

/// "hoy", "ayer", "lunes", "3 oct".
String sessionDateEs(DateTime date, [DateTime? now]) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(date);
  final diff = today.difference(day).inDays;
  const weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  if (diff <= 0) return 'hoy';
  if (diff == 1) return 'ayer';
  if (diff < 7) return weekdays[date.weekday - 1];
  return '${date.day} ${months[date.month - 1]}';
}

/// A finished conversation, laid out for study: every line can be opened to
/// hear it, see it word by word, learn how to answer it and say it aloud.
class SessionReviewPage extends StatelessWidget {
  final String sessionId;
  const SessionReviewPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionReviewCubit(
        sessionId: sessionId,
        repository: getIt<TutorRepository>(),
        reviewer: getIt<TutorReviewService>(),
      ),
      child: const _ReviewView(),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SessionReviewCubit>();
    final state = context.watch<SessionReviewCubit>().state;
    final session = state.session;
    final lesson = cubit.lesson;

    if (session == null) {
      return const Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                AppTopBar(title: 'Repaso'),
                Expanded(
                  child: EmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'Conversación no encontrada',
                    message: 'Solo se guardan las conversaciones más '
                        'recientes con el tutor.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lines = [
      for (final (i, m) in session.messages.indexed)
        if (m.text.trim().isNotEmpty) i,
    ];
    final corrections = session.messages
        .whereType<LearnerLine>()
        .expand((l) => l.notes)
        .where((n) => n is! HintNote)
        .length;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(lesson: lesson, session: session),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.md, Insets.page, Insets.xxxl),
                  children: [
                    Text('Repasa tu conversación',
                        style: context.texts.headlineMedium),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Toca una frase para escucharla, verla palabra por '
                      'palabra, aprender a responderla y decirla tú.',
                      style: context.texts.bodySmall,
                    ),
                    const SizedBox(height: Insets.lg),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      children: [
                        Pill(
                          label: '${lines.length} frases',
                          icon: Icons.notes_rounded,
                          dense: true,
                        ),
                        if (corrections > 0)
                          Pill(
                            label: corrections == 1
                                ? '1 corrección'
                                : '$corrections correcciones',
                            icon: Icons.edit_note_rounded,
                            tone: context.palette.warning,
                            dense: true,
                          ),
                        Pill(
                          label: '${session.studies.length} analizadas',
                          icon: Icons.auto_awesome_rounded,
                          tone: context.palette.gold,
                          dense: true,
                        ),
                      ],
                    ),
                    if (session.summaryEs.isNotEmpty) ...[
                      const SizedBox(height: Insets.lg),
                      AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.format_quote_rounded,
                                color: context.palette.gold, size: 22),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: Text(session.summaryEs,
                                  style: context.texts.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Insets.xl),
                    for (final (n, i) in lines.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: _LineTile(
                          message: session.messages[i],
                          studied: session.studies.containsKey(i),
                          onTap: () => _openStudy(context, lines, n),
                        )
                            .animate()
                            .fadeIn(
                                delay: Motion.stagger(n.clamp(0, 10)),
                                duration: Motion.base)
                            .moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStudy(BuildContext context, List<int> lines, int position) {
    final cubit = context.read<SessionReviewCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _StudySheet(lines: lines, initialPosition: position),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Lesson? lesson;
  final SavedSession session;
  const _Header({required this.lesson, required this.session});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: Insets.xs),
          if (lesson != null) ...[
            Icon(lesson!.icon, size: 20, color: p.gold),
            const SizedBox(width: Insets.sm),
          ],
          Expanded(
            child: Text(lesson?.titleEs ?? 'Conversación',
                style: context.texts.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.only(right: Insets.md),
            child: Text(sessionDateEs(session.date),
                style: context.texts.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// One line in the transcript. Tutor on the left, learner on the right, as
/// in the live conversation, so the review reads like the call did.
class _LineTile extends StatelessWidget {
  final TutorMessage message;
  final bool studied;
  final VoidCallback onTap;

  const _LineTile({
    required this.message,
    required this.studied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final byTutor = message is TutorLine;
    final notes = message is LearnerLine
        ? (message as LearnerLine).notes.where((n) => n is! HintNote).length
        : 0;
    final tone = byTutor ? p.textSecondary : p.gold;

    return Align(
      alignment: byTutor ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
        child: Material(
          color: byTutor ? p.surface : p.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(byTutor ? Radii.sm : Radii.lg),
            topRight: Radius.circular(byTutor ? Radii.lg : Radii.sm),
            bottomLeft: const Radius.circular(Radii.lg),
            bottomRight: const Radius.circular(Radii.lg),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  Insets.lg, Insets.md, Insets.md, Insets.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(byTutor ? Radii.sm : Radii.lg),
                  topRight: Radius.circular(byTutor ? Radii.lg : Radii.sm),
                  bottomLeft: const Radius.circular(Radii.lg),
                  bottomRight: const Radius.circular(Radii.lg),
                ),
                border: Border.all(
                  color: byTutor ? p.border : p.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(byTutor ? 'Tutor' : 'Tú',
                          style: context.texts.labelMedium
                              ?.copyWith(color: tone)),
                      if (notes > 0) ...[
                        const SizedBox(width: Insets.sm),
                        Icon(Icons.edit_note_rounded,
                            size: 15, color: p.warning),
                      ],
                      const Spacer(),
                      if (studied)
                        Semantics(
                          label: 'Ya analizada',
                          child: Icon(Icons.auto_awesome_rounded,
                              size: 14, color: p.gold),
                        ),
                      const SizedBox(width: Insets.xs),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.textMuted),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(message.text,
                      style: context.texts.bodyLarge
                          ?.copyWith(color: p.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The study of one line, with previous/next so a whole conversation can
/// be gone through without closing the sheet.
class _StudySheet extends StatefulWidget {
  final List<int> lines;
  final int initialPosition;
  const _StudySheet({required this.lines, required this.initialPosition});

  @override
  State<_StudySheet> createState() => _StudySheetState();
}

class _StudySheetState extends State<_StudySheet> with TtsPlaybackState {
  late int _position = widget.initialPosition;
  String? _selectedWord;
  final _tts = getIt<TtsService>();

  int get _index => widget.lines[_position];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() => context.read<SessionReviewCubit>().study(_index);

  void _go(int delta) {
    final next = _position + delta;
    if (next < 0 || next >= widget.lines.length) return;
    stopSpeaking();
    setState(() {
      _position = next;
      _selectedWord = null;
    });
    _load();
  }

  Future<void> _sayWord(String word) async {
    setState(() => _selectedWord = word);
    final ok = await _tts.speak(word);
    if (!ok && mounted) showNoVoiceSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<SessionReviewCubit>().state;
    final session = state.session!;
    final message = session.messages[_index];
    final study = session.studies[_index];
    final loading = state.loading.contains(_index);
    final failure = state.failed[_index];
    final byTutor = message is TutorLine;
    final tokens = message.text
        .split(RegExp(r'\s+'))
        .where((t) => WordGloss.normalize(t).isNotEmpty)
        .toList();
    final selectedGloss =
        _selectedWord == null ? null : study?.glossFor(_selectedWord!);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                  Insets.page, 0, Insets.page, Insets.xl),
              children: [
                Row(
                  children: [
                    Pill(
                      label: byTutor ? 'Dijo tu tutor' : 'Dijiste tú',
                      icon: byTutor
                          ? Icons.record_voice_over_outlined
                          : Icons.person_outline_rounded,
                      tone: byTutor ? p.textSecondary : p.gold,
                      dense: true,
                    ),
                    const Spacer(),
                    Text('${_position + 1} / ${widget.lines.length}',
                        style: context.texts.bodySmall),
                  ],
                ),
                const SizedBox(height: Insets.lg),

                // ── The line, every word tappable ─────────────────────────
                Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (final token in tokens)
                      _WordToken(
                        token: token,
                        selected: _selectedWord == token,
                        onTap: () => _sayWord(token),
                      ),
                  ],
                )
                    .animate(key: ValueKey(_index))
                    .fadeIn(duration: Motion.base),
                const SizedBox(height: Insets.sm),
                Text('Toca cualquier palabra para oírla y ver qué significa.',
                    style: context.texts.bodySmall),
                const SizedBox(height: Insets.lg),

                AnimatedSize(
                  duration: Motion.base,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _selectedWord == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: Insets.lg),
                          child: _WordDetail(
                            word: _selectedWord!,
                            gloss: selectedGloss,
                            pending: loading,
                            onPlay: () => _sayWord(_selectedWord!),
                          ),
                        ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: _ListenButton(
                        icon: speaking
                            ? Icons.graphic_eq_rounded
                            : Icons.volume_up_rounded,
                        label: speaking ? 'Suena…' : 'Escuchar',
                        active: speaking,
                        onTap: () => speak(message.text),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: _ListenButton(
                        icon: sequenceSpeaking
                            ? Icons.stop_rounded
                            : Icons.slow_motion_video_rounded,
                        label: sequenceSpeaking ? 'Parar' : 'Palabra a palabra',
                        active: sequenceSpeaking,
                        onTap: () => speakWordByWord(message.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                PhrasePractice(target: message.text),

                const SizedBox(height: Insets.xl),
                if (study != null)
                  _StudyBody(
                    study: study,
                    message: message,
                    selectedWord: _selectedWord,
                    onWord: _sayWord,
                  ).animate(key: ValueKey('study$_index')).fadeIn(
                      duration: Motion.base)
                else if (loading)
                  const _StudySkeleton()
                else if (failure != null)
                  _StudyError(message: failure, onRetry: _load)
                else
                  const SizedBox.shrink(),

                if (message is LearnerLine &&
                    message.notes.isNotEmpty) ...[
                  const SizedBox(height: Insets.xl),
                  const _SectionTitle('Lo que te marcó el tutor'),
                  for (final note in message.notes) ...[
                    TutorNoteCard(note: note),
                    const SizedBox(height: Insets.sm),
                  ],
                ],
              ],
            ),
          ),
          _SheetNav(
            canBack: _position > 0,
            canForward: _position < widget.lines.length - 1,
            onBack: () => _go(-1),
            onForward: () => _go(1),
          ),
        ],
      ),
    );
  }
}

class _WordToken extends StatelessWidget {
  final String token;
  final bool selected;
  final VoidCallback onTap;

  const _WordToken({
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

class _WordDetail extends StatelessWidget {
  final String word;
  final WordGloss? gloss;
  final bool pending;
  final VoidCallback onPlay;

  const _WordDetail({
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

class _StudyBody extends StatelessWidget {
  final LineStudy study;
  final TutorMessage message;
  final String? selectedWord;
  final ValueChanged<String> onWord;

  const _StudyBody({
    required this.study,
    required this.message,
    required this.selectedWord,
    required this.onWord,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Qué significa'),
        Text(study.translationEs,
            style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w500, height: 1.4)),

        if (study.replies.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          const _SectionTitle('Cómo podrías responder'),
          Text('De lo más sencillo a lo más natural.',
              style: context.texts.bodySmall),
          const SizedBox(height: Insets.md),
          for (final (i, reply) in study.replies.indexed) ...[
            _PhraseCard(
              level: reply.level,
              fr: reply.fr,
              es: reply.es,
            ).animate().fadeIn(
                delay: Motion.stagger(i * 2), duration: Motion.base),
            const SizedBox(height: Insets.md),
          ],
        ],

        if (study.betterFr.isNotEmpty &&
            study.betterFr.trim() != message.text.trim()) ...[
          const SizedBox(height: Insets.xl),
          const _SectionTitle('Más natural'),
          _PhraseCard(fr: study.betterFr, es: study.betterNoteEs),
        ] else if (message is LearnerLine && study.betterFr.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          InfoNotice(
            icon: Icons.verified_rounded,
            iconColor: p.good,
            message: 'Lo dijiste tal cual lo diría un francés.',
          ),
        ],

        if (study.words.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          const _SectionTitle('Palabra por palabra'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, w) in study.words.indexed) ...[
                  if (i > 0) Divider(color: p.border, height: 1),
                  _GlossRow(
                    gloss: w,
                    selected: selectedWord != null &&
                        WordGloss.normalize(selectedWord!) ==
                            WordGloss.normalize(w.word),
                    onTap: () => onWord(w.word),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GlossRow extends StatelessWidget {
  final WordGloss gloss;
  final bool selected;
  final VoidCallback onTap;

  const _GlossRow({
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
                      style: context.texts.titleMedium?.copyWith(
                          color: selected ? p.gold : p.textPrimary)),
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
class _PhraseCard extends StatefulWidget {
  final String? level;
  final String fr;
  final String es;

  const _PhraseCard({this.level, required this.fr, required this.es});

  @override
  State<_PhraseCard> createState() => _PhraseCardState();
}

class _PhraseCardState extends State<_PhraseCard> with TtsPlaybackState {
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
                    style: context.texts.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic, height: 1.35)),
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
          const SizedBox(height: Insets.md),
          PhrasePractice(target: widget.fr, compact: true),
        ],
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ListenButton({
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Text(text, style: context.texts.headlineSmall),
      );
}

class _StudySkeleton extends StatelessWidget {
  const _StudySkeleton();

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

class _StudyError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StudyError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final needsKey = message.contains('Ajustes');
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
            child: needsKey
                ? TextButton(
                    onPressed: () => context.push('/settings'),
                    child: const Text('Ir a Ajustes'),
                  )
                : TextButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetNav extends StatelessWidget {
  final bool canBack;
  final bool canForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const _SheetNav({
    required this.canBack,
    required this.canForward,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(Insets.page, Insets.md, Insets.page,
          Insets.md + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canBack ? onBack : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Anterior'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canForward ? onForward : () => Navigator.pop(context),
              icon: Icon(
                  canForward ? Icons.arrow_forward_rounded : Icons.check_rounded,
                  size: 18),
              label: Text(canForward ? 'Siguiente' : 'Terminar'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ],
      ),
    );
  }
}
