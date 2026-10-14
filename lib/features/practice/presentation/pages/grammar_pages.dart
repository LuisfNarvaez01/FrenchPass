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
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// Grammar topics, easiest first; finished ones are ticked.
class GrammarListPage extends StatefulWidget {
  const GrammarListPage({super.key});

  @override
  State<GrammarListPage> createState() => _GrammarListPageState();
}

class _GrammarListPageState extends State<GrammarListPage> {
  final _storage = getIt<StorageService>();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final topics = [...getIt<LearningContent>().grammar]
      ..sort((a, b) => a.level.index.compareTo(b.level.index));
    final done = _storage.getStringSet(StorageKeys.grammarDone);

    return PracticeScaffold(
      title: 'Gramática',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Text(
            'Un tema por tarjeta: la regla en español, ejemplos para escuchar '
            'y cinco ejercicios.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          for (final (i, topic) in topics.indexed) ...[
            AppCard(
              onTap: () async {
                await context.push('/practice/grammar/${topic.id}');
                if (mounted) setState(() {});
              },
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg, vertical: Insets.md),
              child: Row(
                children: [
                  Pill(label: topic.level.label, tone: p.gold, dense: true),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topic.title, style: context.texts.titleMedium),
                        const SizedBox(height: 2),
                        Text(topic.summary,
                            style: context.texts.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  done.contains(topic.id)
                      ? Icon(Icons.check_circle_rounded,
                          color: p.good, size: 20)
                      : Icon(Icons.chevron_right_rounded,
                          color: p.textMuted, size: 20),
                ],
              ),
            ).animate().fadeIn(delay: Motion.stagger(i.clamp(0, 8))),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}

/// One topic: the rule, examples, then its exercises.
class GrammarTopicPage extends StatefulWidget {
  final String topicId;
  const GrammarTopicPage({super.key, required this.topicId});

  @override
  State<GrammarTopicPage> createState() => _GrammarTopicPageState();
}

class _GrammarTopicPageState extends State<GrammarTopicPage> {
  /// -1 while reading the explanation; then the exercise index; past the
  /// end, the summary.
  int _step = -1;
  int _correct = 0;

  GrammarTopic? get _topic => getIt<LearningContent>().topic(widget.topicId);

  Future<void> _answered(bool right) async {
    if (right) {
      _correct++;
      await getIt<ProgressRepository>().recordPractice(PracticeKind.grammar);
    }
  }

  Future<void> _next() async {
    final topic = _topic!;
    if (_step == topic.exercises.length - 1) {
      final storage = getIt<StorageService>();
      final done = storage.getStringSet(StorageKeys.grammarDone)..add(topic.id);
      await storage.setStringSet(StorageKeys.grammarDone, done);
    }
    if (mounted) setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;
    if (topic == null) {
      return const PracticeScaffold(
        title: 'Gramática',
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Tema no encontrado',
          message: 'Vuelve a la lista de temas.',
        ),
      );
    }
    final total = topic.exercises.length;
    if (_step >= total) {
      return PracticeScaffold(
        title: topic.title,
        child: SessionSummary(
          correct: _correct,
          total: total,
          againLabel: 'Repetir los ejercicios',
          onAgain: () => setState(() {
            _step = 0;
            _correct = 0;
          }),
        ),
      );
    }
    if (_step < 0) {
      return _Explanation(
        topic: topic,
        onStart: () => setState(() => _step = 0),
      );
    }
    return PracticeScaffold(
      title: topic.title,
      progress: _step / total,
      child: ChoiceQuestion(
        key: ValueKey(_step),
        item: topic.exercises[_step],
        isLast: _step == total - 1,
        optionsAreFrench: true,
        onAnswered: _answered,
        onNext: _next,
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  final GrammarTopic topic;
  final VoidCallback onStart;
  const _Explanation({required this.topic, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PracticeScaffold(
      title: topic.title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Pill(label: 'Nivel ${topic.level.label}', tone: p.gold, dense: true),
          const SizedBox(height: Insets.md),
          Text(topic.summary, style: context.texts.titleMedium),
          const SizedBox(height: Insets.lg),
          for (final paragraph in topic.explanation) ...[
            Text(paragraph,
                style: context.texts.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: Insets.md),
          ],
          const SizedBox(height: Insets.sm),
          Text('EJEMPLOS', style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, e) in topic.examples.indexed) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.lg, Insets.sm, Insets.sm, Insets.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.fr,
                                  style: context.texts.titleMedium
                                      ?.copyWith(fontStyle: FontStyle.italic)),
                              Text(e.es, style: context.texts.bodySmall),
                            ],
                          ),
                        ),
                        SpeakButton(text: e.fr, size: 40),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Hacer los ${topic.exercises.length} ejercicios'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}
