import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Short graded stories, A1 to B1.
class ReadingListPage extends StatefulWidget {
  const ReadingListPage({super.key});

  @override
  State<ReadingListPage> createState() => _ReadingListPageState();
}

class _ReadingListPageState extends State<ReadingListPage> {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final readings = getIt<LearningContent>().readings;
    final done = getIt<StorageService>().getStringSet(StorageKeys.readingsDone);
    return PracticeScaffold(
      title: 'Lecturas',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Text(
            'Historias cortas por nivel. Toca cualquier palabra para ver qué '
            'significa y escúchalas enteras.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          for (final level in [CefrLevel.a1, CefrLevel.a2, CefrLevel.b1]) ...[
            SectionHeader(
                eyebrow: 'Nivel ${level.label}', title: level.descriptionEs),
            const SizedBox(height: Insets.md),
            for (final r in readings.where((r) => r.level == level)) ...[
              AppCard(
                onTap: () async {
                  await context.push('/practice/readings/${r.id}');
                  if (mounted) setState(() {});
                },
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg, vertical: Insets.md),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: p.gold, size: 22),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: context.texts.titleMedium),
                          Text(r.sentences.first.fr,
                              style: context.texts.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    done.contains(r.id)
                        ? Icon(Icons.check_circle_rounded,
                            color: p.good, size: 20)
                        : Icon(Icons.chevron_right_rounded,
                            color: p.textMuted, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: Insets.sm),
            ],
            const SizedBox(height: Insets.lg),
          ],
        ],
      ),
    );
  }
}

/// A story, word by word, then three comprehension questions.
class ReadingPage extends StatefulWidget {
  final String readingId;
  const ReadingPage({super.key, required this.readingId});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final Set<int> _translated = {};

  /// -1 while reading; then the question index; past the end, the summary.
  int _question = -1;
  int _correct = 0;

  Reading? get _reading => getIt<LearningContent>().reading(widget.readingId);

  void _showWord(String token) {
    final word = getIt<WordRepository>().lookup(token);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _WordSheet(token: token, word: word),
    );
  }

  Future<void> _finish() async {
    final r = _reading!;
    final storage = getIt<StorageService>();
    await storage.setStringSet(StorageKeys.readingsDone,
        storage.getStringSet(StorageKeys.readingsDone)..add(r.id));
    await getIt<ProgressRepository>().recordPractice(PracticeKind.reading);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null) {
      return const PracticeScaffold(
        title: 'Lecturas',
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Lectura no encontrada',
          message: 'Vuelve a la lista.',
        ),
      );
    }
    if (_question >= r.questions.length) {
      return PracticeScaffold(
        title: r.title,
        child: SessionSummary(
          correct: _correct,
          total: r.questions.length,
          againLabel: 'Leer otra vez',
          onAgain: () => setState(() {
            _question = -1;
            _correct = 0;
          }),
        ),
      );
    }
    if (_question >= 0) {
      return PracticeScaffold(
        title: r.title,
        progress: _question / r.questions.length,
        child: ChoiceQuestion(
          key: ValueKey(_question),
          item: r.questions[_question],
          isLast: _question == r.questions.length - 1,
          onAnswered: (right) {
            if (right) _correct++;
          },
          onNext: () async {
            if (_question == r.questions.length - 1) await _finish();
            if (mounted) setState(() => _question++);
          },
        ),
      );
    }

    final p = context.palette;
    return PracticeScaffold(
      title: r.title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Row(
            children: [
              Pill(label: 'Nivel ${r.level.label}', tone: p.gold, dense: true),
              const Spacer(),
              SpeakButton(text: r.text, size: 44, tooltip: 'Escuchar todo'),
            ],
          ),
          const SizedBox(height: Insets.lg),
          for (final (i, sentence) in r.sentences.indexed) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final token in sentence.fr.split(' '))
                  // «, », ?, "2022.": shown, but nothing to look up.
                  if (!RegExp(r'\p{L}', unicode: true).hasMatch(token))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      child: Text(token,
                          style:
                              context.texts.titleMedium?.copyWith(height: 1.5)),
                    )
                  else
                    InkWell(
                      onTap: () => _showWord(token),
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 2),
                        child: Text(token,
                            style: context.texts.titleMedium
                                ?.copyWith(height: 1.5)),
                      ),
                    ),
                InkWell(
                  onTap: () => setState(() {
                    if (!_translated.remove(i)) _translated.add(i);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.translate_rounded,
                        size: 18,
                        color: _translated.contains(i) ? p.gold : p.textMuted,
                        semanticLabel: 'Traducir la frase'),
                  ),
                ),
              ],
            ),
            if (_translated.contains(i))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sentence.es,
                    style: context.texts.bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ).animate().fadeIn(duration: Motion.fast),
            const SizedBox(height: Insets.md),
          ],
          const SizedBox(height: Insets.lg),
          ElevatedButton.icon(
            onPressed: () => setState(() => _question = 0),
            icon: const Icon(Icons.quiz_outlined),
            label: const Text('Responder 3 preguntas'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}

class _WordSheet extends StatelessWidget {
  final String token;
  final Word? word;
  const _WordSheet({required this.token, required this.word});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final w = word;
    final clean =
        token.replaceAll(RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true), '');
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(Insets.page, 0, Insets.page, Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(w?.french ?? clean,
                      style: context.texts.headlineMedium
                          ?.copyWith(color: p.gold)),
                ),
                SpeakButton(text: w?.french ?? clean, size: 44),
              ],
            ),
            if (w != null) ...[
              Text(w.ipa, style: AppTheme.ipa(context, size: 16)),
              const SizedBox(height: Insets.sm),
              Text(w.translationEs, style: context.texts.titleMedium),
              const SizedBox(height: Insets.sm),
              Text(w.exampleFr,
                  style: context.texts.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
              Text(w.exampleEs, style: context.texts.bodySmall),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Text(
                  'Esta forma no está en el catálogo. Toca el ícono de '
                  'traducir al final de la frase para verla entera en '
                  'español.',
                  style: context.texts.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
