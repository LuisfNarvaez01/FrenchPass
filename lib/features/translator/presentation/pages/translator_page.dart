import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/tts_playback_mixin.dart';
import 'package:french_pass/features/translator/data/translator_repository.dart';
import 'package:french_pass/features/translator/domain/translation.dart';
import 'package:french_pass/features/translator/presentation/cubit/translator_cubit.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/presentation/pages/session_review_page.dart';
import 'package:french_pass/features/tutor/presentation/widgets/phrase_practice.dart';
import 'package:french_pass/features/tutor/presentation/widgets/study_widgets.dart';

/// Spanish in, French out -- taken apart the way the tutor review does it:
/// every word, other ways to say it, and what the sentence teaches.
class TranslatorPage extends StatelessWidget {
  const TranslatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranslatorCubit(
        translations: getIt<TranslatorRepository>(),
        tutor: getIt<TutorRepository>(),
        gemini: getIt<TutorReviewService>(),
      ),
      child: const _TranslatorView(),
    );
  }
}

class _TranslatorView extends StatefulWidget {
  const _TranslatorView();

  @override
  State<_TranslatorView> createState() => _TranslatorViewState();
}

class _TranslatorViewState extends State<_TranslatorView> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _translate() {
    _focus.unfocus();
    context.read<TranslatorCubit>().translate(_input.text);
  }

  void _open(Translation t) {
    _input.text = t.sourceEs;
    context.read<TranslatorCubit>().open(t);
  }

  void _startOver() {
    _input.clear();
    context.read<TranslatorCubit>().clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TranslatorCubit>().state;
    final current = state.current;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'Traductor'),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.md, Insets.page, Insets.xxxl),
                  children: [
                    Text('Escríbelo en español',
                        style: context.texts.headlineMedium),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Te lo paso al francés palabra por palabra y te digo '
                      'si un francés lo diría de otra forma.',
                      style: context.texts.bodySmall,
                    ),
                    const SizedBox(height: Insets.lg),
                    _InputCard(
                      controller: _input,
                      focus: _focus,
                      loading: state.loading,
                      onSubmit: _translate,
                    ),
                    const SizedBox(height: Insets.xl),
                    if (state.loading)
                      const StudySkeleton()
                    else if (state.error != null)
                      StudyError(message: state.error!, onRetry: _translate)
                    else if (current != null) ...[
                      _Result(translation: current),
                      const SizedBox(height: Insets.xl),
                      OutlinedButton.icon(
                        onPressed: _startOver,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Traducir otra frase'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                      ),
                    ] else if (state.history.isNotEmpty)
                      _History(
                        items: state.history,
                        onOpen: _open,
                        onDelete: context.read<TranslatorCubit>().delete,
                      )
                    else
                      const InfoNotice(
                        icon: Icons.lightbulb_outline_rounded,
                        message: 'Prueba con algo que dirías hoy: "Quiero '
                            'un café con leche, por favor" o "Llego tarde '
                            'porque había tráfico".',
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
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool loading;
  final VoidCallback onSubmit;

  const _InputCard({
    required this.controller,
    required this.focus,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: p.border),
    );
    final empty = controller.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focus,
          minLines: 2,
          maxLines: 5,
          maxLength: TranslatorCubit.maxLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          style: context.texts.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Por ejemplo: ¿Dónde está la estación de tren?',
            hintStyle: context.texts.bodyMedium?.copyWith(color: p.textMuted),
            suffixIcon: empty
                ? null
                : IconButton(
                    icon:
                        Icon(Icons.close_rounded, size: 18, color: p.textMuted),
                    tooltip: 'Borrar',
                    onPressed: controller.clear,
                  ),
            filled: true,
            fillColor: p.surface,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide: BorderSide(color: p.gold, width: 1.5)),
          ),
        ),
        const SizedBox(height: Insets.sm),
        ElevatedButton.icon(
          onPressed: empty || loading ? null : onSubmit,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.translate_rounded, size: 18),
          label: Text(loading ? 'Traduciendo…' : 'Traducir al francés'),
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}

/// The French, every word tappable, then the breakdown.
class _Result extends StatefulWidget {
  final Translation translation;
  const _Result({required this.translation});

  @override
  State<_Result> createState() => _ResultState();
}

class _ResultState extends State<_Result> with TtsPlaybackState {
  final _tts = getIt<TtsService>();
  String? _selectedWord;

  @override
  void didUpdateWidget(_Result old) {
    super.didUpdateWidget(old);
    if (old.translation.id != widget.translation.id) _selectedWord = null;
  }

  Future<void> _sayWord(String word) async {
    setState(() => _selectedWord = word);
    final ok = await _tts.speak(word);
    if (!ok && mounted) showNoVoiceSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = widget.translation;
    final tokens = t.fr
        .split(RegExp(r'\s+'))
        .where((w) => WordGloss.normalize(w).isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('EN FRANCÉS', style: AppTheme.eyebrow(context)),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: 2,
                runSpacing: 4,
                children: [
                  for (final token in tokens)
                    WordToken(
                      token: token,
                      selected: _selectedWord == token,
                      onTap: () => _sayWord(token),
                    ),
                ],
              ),
              if (t.literalEs.isNotEmpty) ...[
                const SizedBox(height: Insets.md),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'Literalmente: ',
                      style: context.texts.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: t.literalEs,
                      style: context.texts.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: Insets.lg),
              Row(
                children: [
                  Expanded(
                    child: ListenButton(
                      icon: speaking
                          ? Icons.graphic_eq_rounded
                          : Icons.volume_up_rounded,
                      label: speaking ? 'Suena…' : 'Escuchar',
                      active: speaking,
                      onTap: () => speak(t.fr),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: ListenButton(
                      icon: sequenceSpeaking
                          ? Icons.stop_rounded
                          : Icons.slow_motion_video_rounded,
                      label: sequenceSpeaking ? 'Parar' : 'Palabra a palabra',
                      active: sequenceSpeaking,
                      onTap: () => speakWordByWord(t.fr),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              PhrasePractice(target: t.fr),
            ],
          ),
        ).animate(key: ValueKey(t.id)).fadeIn(duration: Motion.base),
        const SizedBox(height: Insets.md),
        Text('Toca una palabra para oírla y ver qué significa.',
            style: context.texts.bodySmall),
        AnimatedSize(
          duration: Motion.base,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _selectedWord == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Insets.md),
                  child: WordDetail(
                    word: _selectedWord!,
                    gloss: t.glossFor(_selectedWord!),
                    pending: false,
                    onPlay: () => _sayWord(_selectedWord!),
                  ),
                ),
        ),
        if (t.words.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          const StudySectionTitle('Palabra por palabra'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, w) in t.words.indexed) ...[
                  if (i > 0) Divider(color: p.border, height: 1),
                  GlossRow(
                    gloss: w,
                    selected: _selectedWord != null &&
                        WordGloss.normalize(_selectedWord!) ==
                            WordGloss.normalize(w.word),
                    onTap: () => _sayWord(w.word),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (t.alternatives.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          const StudySectionTitle('Otras formas de decirlo'),
          Text('Elige según con quién hables.', style: context.texts.bodySmall),
          const SizedBox(height: Insets.md),
          for (final (i, a) in t.alternatives.indexed) ...[
            PhraseCard(level: a.register, fr: a.fr, es: a.es, note: a.noteEs)
                .animate()
                .fadeIn(delay: Motion.stagger(i * 2), duration: Motion.base),
            const SizedBox(height: Insets.md),
          ],
        ],
        if (t.notesEs.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          const StudySectionTitle('Fíjate en esto'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, note) in t.notesEs.indexed) ...[
                  if (i > 0) const SizedBox(height: Insets.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.push_pin_outlined,
                            size: 16, color: p.gold),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(note,
                            style: context.texts.bodyMedium
                                ?.copyWith(color: p.textPrimary)),
                      ),
                    ],
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

class _History extends StatelessWidget {
  final List<Translation> items;
  final ValueChanged<Translation> onOpen;
  final ValueChanged<Translation> onDelete;

  const _History({
    required this.items,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudySectionTitle('Lo que ya tradujiste'),
        Text('Desliza una frase hacia un lado para borrarla.',
            style: context.texts.bodySmall),
        const SizedBox(height: Insets.md),
        for (final (i, t) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Dismissible(
              key: ValueKey(t.id),
              onDismissed: (_) => onDelete(t),
              child: AppCard(
                onTap: () => onOpen(t),
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg, vertical: Insets.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.sourceEs,
                              style: context.texts.bodyMedium
                                  ?.copyWith(color: p.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(t.fr,
                              style: context.texts.bodyMedium?.copyWith(
                                  color: p.gold, fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(sessionDateEs(t.date), style: context.texts.bodySmall),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: p.textMuted),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(
              delay: Motion.stagger(i.clamp(0, 8)), duration: Motion.base),
      ],
    );
  }
}
