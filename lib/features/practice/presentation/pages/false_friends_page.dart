import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// French words that look Spanish and mean something else: browse them,
/// then test yourself.
class FalseFriendsPage extends StatefulWidget {
  const FalseFriendsPage({super.key});

  @override
  State<FalseFriendsPage> createState() => _FalseFriendsPageState();
}

class _FalseFriendsPageState extends State<FalseFriendsPage> {
  static const _quizLength = 8;
  final _all = getIt<LearningContent>().falseFriends;

  List<(FalseFriend, ChoiceItem)>? _quiz;
  int _index = 0;
  int _correct = 0;

  void _startQuiz() {
    final rng = Random();
    final pool = [..._all]..shuffle(rng);
    setState(() {
      _index = 0;
      _correct = 0;
      _quiz = [
        for (final f in pool.take(_quizLength)) (f, _questionFor(f, rng)),
      ];
    });
  }

  /// The trap (what a Spanish speaker guesses) is always among the options.
  ChoiceItem _questionFor(FalseFriend f, Random rng) {
    final others = (_all.where((o) => o != f).toList()..shuffle(rng))
        .take(2)
        .map((o) => o.means);
    final options = {f.means, f.trap, ...others}.toList()..shuffle(rng);
    return ChoiceItem(
      prompt: '¿Qué significa «${f.fr}»?',
      options: options,
      answer: options.indexOf(f.means),
      why: 'No es «${f.trap}». «${f.trap}» se dice ${f.say}. '
          '${f.exampleFr} = ${f.exampleEs}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _quiz;
    if (quiz != null) {
      if (_index >= quiz.length) {
        return PracticeScaffold(
          title: 'Falsos amigos',
          child: SessionSummary(
            correct: _correct,
            total: quiz.length,
            onAgain: _startQuiz,
          ),
        );
      }
      return PracticeScaffold(
        title: 'Falsos amigos',
        progress: _index / quiz.length,
        child: ChoiceQuestion(
          key: ValueKey(_index),
          item: quiz[_index].$2,
          isLast: _index == quiz.length - 1,
          header: Align(
            alignment: Alignment.centerLeft,
            child: SpeakButton(text: quiz[_index].$1.fr, size: 44),
          ),
          onAnswered: (right) async {
            if (!right) return;
            _correct++;
            await getIt<ProgressRepository>()
                .recordPractice(PracticeKind.falseFriends);
          },
          onNext: () => setState(() => _index++),
        ),
      );
    }

    final p = context.palette;
    final sorted = [..._all]
      ..sort((a, b) => a.level.index.compareTo(b.level.index));
    return PracticeScaffold(
      title: 'Falsos amigos',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Text(
            'Se parecen al español pero significan otra cosa. Son los errores '
            'que más delatan a un hispanohablante.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          ElevatedButton.icon(
            onPressed: _startQuiz,
            icon: const Icon(Icons.quiz_outlined),
            label: const Text('Ponte a prueba'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: Insets.xl),
          for (final (i, f) in sorted.indexed) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(f.fr,
                            style: context.texts.headlineSmall
                                ?.copyWith(color: p.gold)),
                      ),
                      Pill(
                          label: f.level.label,
                          tone: p.textSecondary,
                          dense: true),
                      SpeakButton(text: f.fr, size: 40),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'Significa: ',
                        style: context.texts.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    TextSpan(text: f.means, style: context.texts.bodyMedium),
                  ])),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'No es «${f.trap}»: ',
                        style: context.texts.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, color: p.critical)),
                    TextSpan(
                        text: 'eso se dice ${f.say}.',
                        style: context.texts.bodyMedium),
                  ])),
                  const SizedBox(height: Insets.sm),
                  Text(f.exampleFr,
                      style: context.texts.bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic)),
                  Text(f.exampleEs, style: context.texts.bodySmall),
                ],
              ),
            ).animate().fadeIn(delay: Motion.stagger(i.clamp(0, 6))),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}
