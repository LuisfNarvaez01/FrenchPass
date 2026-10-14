import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/text/answer_check.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/conjugation/domain/conjugator.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

/// The verb list, with a search and the way into practice.
class ConjugationPage extends StatefulWidget {
  const ConjugationPage({super.key});

  @override
  State<ConjugationPage> createState() => _ConjugationPageState();
}

class _ConjugationPageState extends State<ConjugationPage> {
  String _query = '';
  final Set<Tense> _tenses = {Tense.present};

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = WordRepository.fold(_query);
    final verbs = Verbs.all
        .where((v) =>
            q.isEmpty ||
            WordRepository.fold(v.display).contains(q) ||
            WordRepository.fold(v.es).contains(q))
        .toList();

    return PracticeScaffold(
      title: 'Conjugación',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          AppCard(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRACTICAR', style: AppTheme.eyebrow(context)),
                const SizedBox(height: Insets.sm),
                Text('Elige los tiempos y escribe 10 formas.',
                    style: context.texts.bodySmall),
                const SizedBox(height: Insets.md),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final t in Tense.values)
                      FilterChip(
                        label: Text(t.labelEs),
                        selected: _tenses.contains(t),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _tenses.add(t);
                          } else if (_tenses.length > 1) {
                            _tenses.remove(t);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConjugationDrillPage(
                          tenses: _tenses.toList()..sort(_byIndex)),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Empezar'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Buscar verbo en francés o español',
              prefixIcon: Icon(Icons.search_rounded, color: p.textMuted),
              filled: true,
              fillColor: p.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide(color: p.border),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          Text('${verbs.length} verbos', style: context.texts.bodySmall),
          const SizedBox(height: Insets.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, v) in verbs.indexed) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  // Its own Material, or the card's fill hides the ink.
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(v.display, style: context.texts.titleMedium),
                      subtitle: Text(v.es, style: context.texts.bodySmall),
                      trailing: v.isIrregular
                          ? Pill(
                              label: 'irregular',
                              tone: p.terracotta,
                              dense: true)
                          : null,
                      onTap: () => context.push(
                          '/practice/conjugation/${Uri.encodeComponent(v.display)}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _byIndex(Tense a, Tense b) => a.index.compareTo(b.index);
}

/// One verb in all four tenses, every form playable.
class VerbPage extends StatelessWidget {
  final String verb;
  const VerbPage({super.key, required this.verb});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = Verbs.byInfinitive(verb);
    if (v == null) {
      return const PracticeScaffold(
        title: 'Conjugación',
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Verbo no encontrado',
          message: 'Vuelve a la lista de verbos.',
        ),
      );
    }
    return PracticeScaffold(
      title: v.display,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.md, Insets.page, Insets.xxxl),
        children: [
          Text(v.es, style: context.texts.titleMedium),
          const SizedBox(height: Insets.xs),
          Text(
            [
              if (v.isIrregular) 'Verbo irregular.',
              v.usesEtre
                  ? 'Forma el pasado compuesto con être.'
                  : 'Forma el pasado compuesto con avoir.',
            ].join(' '),
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          for (final tense in Tense.values) ...[
            Text(tense.labelEs.toUpperCase(), style: AppTheme.eyebrow(context)),
            Text(tense.useEs, style: context.texts.bodySmall),
            const SizedBox(height: Insets.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, person) in Person.values.indexed) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.lg, Insets.xs, Insets.xs, Insets.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Conjugator.conjugate(v, tense, person),
                              style: context.texts.bodyLarge,
                            ),
                          ),
                          SpeakButton(
                            text: Conjugator.conjugate(v, tense, person)
                                .replaceAll(RegExp(r'\([a-z]+\)'), ''),
                            size: 36,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),
          ],
        ],
      ),
    );
  }
}

/// Ten forms to type: verb, tense and person given.
class ConjugationDrillPage extends StatefulWidget {
  final List<Tense> tenses;
  const ConjugationDrillPage({super.key, required this.tenses});

  @override
  State<ConjugationDrillPage> createState() => _ConjugationDrillPageState();
}

class _ConjugationDrillPageState extends State<ConjugationDrillPage> {
  static const _length = 10;

  /// The most common verbs come up most: the first 40 of the list.
  static const _core = 40;

  late List<(Verb, Tense, Person)> _items;
  int _index = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    final rng = Random();
    const verbs = Verbs.all;
    _items = [
      for (var i = 0; i < _length; i++)
        (
          verbs[rng.nextDouble() < 0.75
              ? rng.nextInt(_core)
              : rng.nextInt(verbs.length)],
          widget.tenses[rng.nextInt(widget.tenses.length)],
          Person.values[rng.nextInt(Person.values.length)],
        ),
    ];
    _index = 0;
    _correct = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _items.length) {
      return PracticeScaffold(
        title: 'Conjugación',
        child: SessionSummary(
          correct: _correct,
          total: _items.length,
          onAgain: () => setState(_build),
        ),
      );
    }
    final p = context.palette;
    final (verb, tense, person) = _items[_index];
    final expected = Conjugator.conjugate(verb, tense, person);

    return PracticeScaffold(
      title: 'Conjugación',
      progress: _index / _items.length,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.lg, Insets.page, Insets.xxxl),
        children: [
          Text(verb.display,
              style: context.texts.displaySmall?.copyWith(color: p.gold)),
          Text(verb.es, style: context.texts.bodySmall),
          const SizedBox(height: Insets.lg),
          Wrap(
            spacing: Insets.sm,
            children: [
              Pill(label: tense.labelEs, tone: p.terracotta),
              Pill(label: person.label, tone: p.textSecondary),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text('Escribe la frase con el pronombre: «${person.subject} ...»',
              style: context.texts.bodySmall),
          const SizedBox(height: Insets.lg),
          TypedAnswer(
            key: ValueKey(_index),
            expected: expected,
            isLast: _index == _items.length - 1,
            hint: '${person.subject} ...',
            onChecked: (match) async {
              if (!match.isRight) return;
              _correct++;
              await getIt<ProgressRepository>()
                  .recordPractice(PracticeKind.conjugation);
            },
            onNext: () => setState(() => _index++),
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: SpeakButton(
              text: expected.replaceAll(RegExp(r'\([a-z]+\)'), ''),
              size: 44,
            ),
          ),
        ],
      ),
    );
  }
}
